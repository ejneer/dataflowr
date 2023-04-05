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

  recur <- function(sym_name) {
    if (is_function(sym_name, envir)) {
      formals_names <- fn_fmls_names(as_function(sym_name, envir))

      # arguments to this function that aren't in the planning environment
      unresolved <- setdiff(formals_names, env_names(env_plan))

      # make sure all arguments are resolved to a call or symbol
      walk(unresolved, recur)

      if (is.null(formals_names)) {
        # bare function call (i.e. no arguments)
        new_call <- call2(sym_name)
      } else {
        # call with arguments from the planning environment
        new_call <- call2(sym_name, !!!env_get_list(env_plan, formals_names))
      }

      env_bind(env_plan, !!sym_name := new_call)
    } else {
      # its just a symbol
      env_bind(env_plan, !!sym_name := sym(sym_name))
    }
  }
  recur(fun_name)

  env_plan
}
#' Is `name` a function in `envir`?
#'
#' @param name string name of an object
#' @param envir environment in which to look for `name`
#' @return boolean
#' @noRd
is_function <- function(name, envir) {
  name %in% lsf.str(envir)
}
