#' Solve the order of function calls in a flow of data
#'
#' Determines the order in which function dependencies need to be called such
#' that `fun`'s arguments are all resolved before it is called. A notion of a
#' "planning" environment is used (and ulimately returned), wherein function
#' calls from `env` are translated into synonymous call objects with their
#' arguments replaced by other function calls or symbols where appropriate.
#'
#' @param fun function at the end of the data flow
#' @param env environment of functions involved
#' @return environment with function args replaced with call objects
#' @export
solve_dataflow <- function(fun_name, envir) {
  env_plan <- new_environment(parent = envir)

  is_function <- function(name) {
    name %in% lsf.str(envir)
  }

  formals_from_plan <- function(formals_names) {
    if (!is.null(formals_names)) {
      env_get_list(env_plan, formals_names)
    } else {
      list()
    }
  }

  recur <- function(sym_name) {
    if (is_function(sym_name)) {
      formals_names <- fn_fmls_names(as_function(sym_name, envir))

      # arguments to this function that aren't in the planning environment
      unresolved <- setdiff(formals_names, env_names(env_plan))

      # make sure all arguments are resolved to a call or symbol
      walk(unresolved, recur)

      env_bind(
        env_plan,
        !!sym_name := call2(sym_name, !!!formals_from_plan(formals_names))
      )
    } else {
      # its just a symbol
      env_bind(env_plan, !!sym_name := sym(sym_name))
    }
  }
  recur(fun_name)

  env_plan
}
