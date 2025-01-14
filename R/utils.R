commas <- function(x) paste(x, collapse = ", ")

voc_lookup <- function(x, voc, join_var, ds_name) {
  join_by <- "champs_local_code"
  names(join_by) <- join_var
  old_var_new_name <- paste0(join_var, "_code")

  res <- x %>%
    mutate(
      "{join_var}" := substr(.data[[join_var]], 1, 7),
      "{old_var_new_name}" := .data[[join_var]]
    ) %>%
    left_join(select(voc, one_of(c("champs_local_code", "c_name"))),
      by = join_by) %>%
    select(-.data[[join_var]]) %>%
    rename("{join_var}" := "c_name")
  cli::cli_alert_success("Used CHAMPS vocabulary to transform \\
    '{join_var}' in {ds_name}", wrap = TRUE)

  not_handled <- setdiff(unique(
    x[[old_var_new_name]][is.na(x[[join_var]])]), NA)
  nnh <- length(not_handled)
  if (nnh > 0) {
    cli::cli_alert_warning("After transforming {join_var}, found {nnh} \\
      code{?s} that do not match with any codes found in the \\
      CHAMPS vocabulary file: {commas(not_handled)}",
      wrap = TRUE)
  }

  res
}

check_valid_vals <- function(x, variable, valid, name, ds_name) {
  var_diff <- setdiff(unique(x[[variable]]), c(valid, NA))
  assertthat::assert_that(length(var_diff) == 0,
    msg = cli::format_error("{ds_name} contains {name} that are not in \\
      expected: {commas(var_diff)}"))
  cli::cli_alert_success("Checked that values for '{variable}' in the \\
    {ds_name} are correct", wrap = TRUE)
}

# transform so age is a factor/level instead of its own column
dss_transform <- function(dss) {
  dplyr::bind_rows(
    dss %>% dplyr::select(!"age"),
    dss %>%
      dplyr::group_by(
        .data$site, .data$catchment, .data$age, .data$factor,
        .data$period_start_year, .data$period_end_year
      ) %>%
      dplyr::summarise(n = sum(.data$n), .groups = "drop") %>%
      dplyr::group_by(
        .data$site, .data$catchment, .data$age,
        .data$period_start_year, .data$period_end_year
      ) %>%
      dplyr::summarise(n = max(.data$n)) %>%
      dplyr::mutate(factor = "age", level = .data$age) %>%
      dplyr::ungroup() %>%
      dplyr::select(!"age")
  )
}

#' Get a list of valid conditions found in the causal chain
#' @param x an object read in from [read_and_validate_data()]
#' @export
valid_conditions <- function(x) {
  assertthat::assert_that(inherits(x, "champs_processed"),
    msg = cli::format_error("Data must come from process_data()")
  )

  tmp <- dplyr::tibble(
    condition = c(
      x$ads$ic_champs_group_desc,
      x$ads$uc_champs_group_desc,
      x$ads$morbid_cond_01_champs_group_desc,
      x$ads$morbid_cond_02_champs_group_desc,
      x$ads$morbid_cond_03_champs_group_desc,
      x$ads$morbid_cond_04_champs_group_desc,
      x$ads$morbid_cond_05_champs_group_desc,
      x$ads$morbid_cond_06_champs_group_desc,
      x$ads$morbid_cond_07_champs_group_desc,
      x$ads$morbid_cond_08_champs_group_desc
    )
  ) %>%
  dplyr::filter(!is.na(.data$condition)) %>%
  dplyr::count(.data$condition) %>%
  dplyr::arrange(-.data$n) %>%
  dplyr::mutate("causal chain rank" = seq_len(dplyr::n())) %>%
  dplyr::select(-c("n"))

  # if (message)
  #   cli::cli_alert_info("note: a higher rank means the condition was found \\
  #     more frequently somewhere in the causal chain than lower ranks",
  #     wrap = TRUE)
  tmp
}
