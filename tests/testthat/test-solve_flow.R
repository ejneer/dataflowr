test_that("a dag of functions and symbols can be solved and executed", {
  returns_1 <- function() 1
  returns_2 <- function() 2
  calculates <- function(returns_1, returns_2, c) sum(returns_1, returns_2, c)

  expected_env <- env(
    returns_1 = call2("returns_1"),
    returns_2 = call2("returns_2"),
    c = sym("c"),
    calculates = call2(
      "calculates",
      returns_1 = call2("returns_1"),
      returns_2 = call2("returns_2"),
      c = sym("c")
    )
  )

  solved_env <- solve_dataflow("calculates", current_env())

  expect_equal(solved_env, expected_env)
  expect_equal(
    eval(expected_env$calculates, list(c = 3)),
    eval(solved_env$calculates, list(c = 3))
  )
})
