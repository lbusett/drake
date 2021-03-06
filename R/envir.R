assign_to_envir <- function(targets, values, config){
  if (config$lazy_load){
    return()
  }
  lightly_parallelize(
    X = seq_along(along.with = targets),
    FUN = assign_to_envir_single,
    jobs = config$jobs,
    targets = targets,
    values = values,
    config = config
  )
  invisible()
}

assign_to_envir_single <- function(index, targets, values, config){
  target <- targets[index]
  value <- values[[index]]
  if (is_file(target) | !(target %in% config$plan$target)){
    return()
  }
  assign(x = target, value = value, envir = config$envir)
  invisible()
}

prune_envir <- function(targets, config){
  downstream <- downstream_nodes(
    from = targets, graph = config$graph, jobs = config$jobs)
  already_loaded <- ls(envir = config$envir, all.names = TRUE) %>%
    intersect(y = config$plan$target)
  load_these <- nonfile_target_dependencies(
    targets = targets,
    config = config
    ) %>%
    setdiff(y = c(targets, already_loaded))
  keep_these <- nonfile_target_dependencies(
    targets = downstream,
    config = config
  )
  discard_these <- setdiff(x = config$plan$target, y = keep_these) %>%
    parallel_filter(f = is_not_file, jobs = config$jobs) %>%
    intersect(y = already_loaded)
  if (length(discard_these)){
    console_many_targets(
      discard_these,
      pattern = "unload",
      config = config
    )
    rm(list = discard_these, envir = config$envir)
  }
  if (length(load_these)){
    if (!config$lazy_load){
      console_many_targets(
        load_these,
        pattern = "load",
        config = config
      )
    }
    loadd(list = load_these, envir = config$envir, cache = config$cache,
      verbose = FALSE, lazy = config$lazy_load)
  }
  invisible()
}

nonfile_target_dependencies <- function(targets, config){
  deps <- dependencies(targets = targets, config = config)
  out <- parallel_filter(x = deps, f = is_not_file, jobs = config$jobs)
  intersect(out, config$plan$target)
}
