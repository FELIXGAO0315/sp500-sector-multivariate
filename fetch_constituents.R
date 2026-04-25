#' fetch_constituents.R
#'
#' Pulls daily adjusted-close prices for S&P 500 constituents in two
#' GICS sectors (Information Technology + Health Care) from Yahoo Finance,
#' computes log-returns, drops tickers without full coverage in the
#' sample window, and writes two cache files:
#'
#'   constituents_returns_cache.rds   xts of daily log-returns (n x p)
#'   constituents_meta.rds            list with tickers, sectors, drops, etc.
#'
#' Sample window matches the ETF analysis: 2018-01-02 to 2024-12-31.
#' Run from the project root:
#'
#'   Rscript fetch_constituents.R
#'
#' Re-running is a no-op once the cache exists; delete the .rds files to
#' force a refresh.
#' ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  pkgs <- c("quantmod", "rvest", "xts", "zoo",
            "dplyr", "tibble", "stringr")
  for (p in pkgs) {
    if (!requireNamespace(p, quietly = TRUE))
      install.packages(p, repos = "https://cloud.r-project.org")
    library(p, character.only = TRUE)
  }
})

# ---- Configuration --------------------------------------------------------
START_DATE   <- as.Date("2018-01-02")
END_DATE     <- as.Date("2024-12-31")
SECTOR_X     <- "Information Technology"   # cyclical group
SECTOR_Y     <- "Health Care"              # defensive group
WIKI_URL     <- "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
CACHE_PATH   <- "constituents_returns_cache.rds"
META_PATH    <- "constituents_meta.rds"
MIN_COVERAGE <- 1.0     # require full-period coverage; 0.95 to allow gaps
SLEEP_SEC    <- 0.15    # polite pause between Yahoo calls
MAX_RETRIES  <- 1       # one retry per ticker on transient failure

# ---- Tier 1: local cache --------------------------------------------------
if (file.exists(CACHE_PATH) && file.exists(META_PATH)) {
  message("Cache found at ", CACHE_PATH,
          " -- skipping fetch. Delete it to force a refresh.")
  quit(save = "no", status = 0)
}

# ---- Step 1: GICS-sector-tagged constituent list from Wikipedia -----------
# Wikipedia's table id is stable ("constituents"); column names have been
# stable for years but we name them positionally as a defensive fallback.
message("Fetching S&P 500 constituent list from Wikipedia...")

constituents <- tryCatch({
  page <- read_html(WIKI_URL)
  tbl  <- page %>% html_element("table#constituents") %>% html_table()
  if (!all(c("Symbol", "Security", "GICS Sector") %in% colnames(tbl))) {
    # Column-name change defence: assume positional layout
    colnames(tbl)[1:3] <- c("Symbol", "Security", "GICS Sector")
  }
  tibble(
    ticker = tbl$Symbol,
    name   = tbl$Security,
    sector = tbl$`GICS Sector`
  )
}, error = function(e) {
  stop("Failed to scrape Wikipedia constituents: ",
       conditionMessage(e),
       "\nCheck network or table structure at: ", WIKI_URL)
})

stopifnot(nrow(constituents) > 400)
message(sprintf("Got %d constituents.", nrow(constituents)))

# ---- Step 2: filter to two target sectors ---------------------------------
# Yahoo uses '-' where Wikipedia/CRSP use '.' for share classes (BRK.B etc.).
target <- constituents %>%
  filter(sector %in% c(SECTOR_X, SECTOR_Y)) %>%
  mutate(yahoo_ticker = str_replace_all(ticker, "\\.", "-"))

n_x <- sum(target$sector == SECTOR_X)
n_y <- sum(target$sector == SECTOR_Y)
message(sprintf("  %-25s : %d tickers", SECTOR_X, n_x))
message(sprintf("  %-25s : %d tickers", SECTOR_Y, n_y))
stopifnot(n_x >= 20, n_y >= 20)

# ---- Step 3: fetch adjusted close from Yahoo (with retry) -----------------
fetch_one <- function(yt, from, to, retries = MAX_RETRIES) {
  for (k in 0:retries) {
    res <- tryCatch({
      px <- quantmod::getSymbols(yt, src = "yahoo",
                                 from = from, to = to,
                                 auto.assign = FALSE, warnings = FALSE)
      Ad(px)
    }, error = function(e) NULL)
    if (!is.null(res) && nrow(res) > 0) return(res)
    if (k < retries) Sys.sleep(0.5)
  }
  NULL
}

message(sprintf("Fetching %d series from Yahoo Finance...",
                nrow(target)))

prices_list <- vector("list", nrow(target))
failed      <- character(0)

for (i in seq_len(nrow(target))) {
  yt <- target$yahoo_ticker[i]
  px <- fetch_one(yt, START_DATE, END_DATE)
  if (is.null(px)) {
    message(sprintf("  [%3d/%3d] %-6s -- FAILED",
                    i, nrow(target), yt))
    failed <- c(failed, yt)
  } else {
    colnames(px)     <- yt
    prices_list[[i]] <- px
    if (i %% 25 == 0 || i == nrow(target))
      message(sprintf("  [%3d/%3d] done", i, nrow(target)))
  }
  Sys.sleep(SLEEP_SEC)
}

prices_list <- prices_list[!sapply(prices_list, is.null)]
target_ok   <- target %>%
  filter(yahoo_ticker %in% sapply(prices_list, function(x) colnames(x)[1]))

if (length(failed) > 0)
  message("Failed tickers (", length(failed), "): ",
          paste(failed, collapse = ", "))

# ---- Step 4: align on a common business-day calendar ----------------------
prices_xts <- do.call(merge, prices_list)
prices_xts <- prices_xts[paste0(START_DATE, "/", END_DATE)]

# ---- Step 5: drop tickers without full-period coverage --------------------
# These are typically post-2018 IPOs (e.g., COIN, ABNB) or stocks
# that were delisted/acquired during the window. Keeping them would
# require imputation we don't want.
n_days   <- nrow(prices_xts)
coverage <- colSums(!is.na(prices_xts)) / n_days
keep     <- coverage >= MIN_COVERAGE

dropped_ipo <- names(coverage)[!keep]
if (length(dropped_ipo) > 0)
  message("Dropped for incomplete coverage (",
          length(dropped_ipo), "): ",
          paste(dropped_ipo, collapse = ", "))

prices_xts <- prices_xts[, keep]
target_ok  <- target_ok %>%
  filter(yahoo_ticker %in% colnames(prices_xts))

# ---- Step 6: log returns --------------------------------------------------
log_returns <- diff(log(prices_xts))
log_returns <- log_returns[-1, ]            # drop the leading NA row
log_returns <- na.omit(log_returns)         # paranoia; should be a no-op

# Final sanity
final_n <- nrow(log_returns)
final_p <- ncol(log_returns)
final_x <- sum(target_ok$sector == SECTOR_X)
final_y <- sum(target_ok$sector == SECTOR_Y)

message(sprintf(
  "\nFinal panel: n = %d days, p = %d stocks  (%d %s + %d %s)",
  final_n, final_p, final_x, SECTOR_X, final_y, SECTOR_Y))

# ---- Step 7: save cache --------------------------------------------------
meta <- list(
  start_date  = START_DATE,
  end_date    = END_DATE,
  sectors     = c(SECTOR_X, SECTOR_Y),
  tickers     = target_ok,            # tibble: ticker, name, sector, yahoo_ticker
  n_obs       = final_n,
  n_stocks    = final_p,
  failed      = failed,
  dropped_ipo = dropped_ipo,
  source      = "Yahoo Finance via quantmod",
  index_url   = WIKI_URL,
  fetched_at  = Sys.time(),
  r_version   = R.version.string
)

saveRDS(log_returns, CACHE_PATH)
saveRDS(meta,        META_PATH)

message("\nWrote ", CACHE_PATH, " and ", META_PATH)
message("Done.")
