
<!-- README.md is generated from README.Rmd. Please edit that file -->

# dataflowR

dataflowR is a small library inspired by python’s Hamilton library that
intends to ease the creation and running of dataflows, pipelines, DAGs,
whatever you want to call them. They’re all a series of ordered
transformations on data. Transformation steps (i.e. a DAG) are encoded
using function and argument names. In a given environment, if a function
takes an argument that is named the same as another function, it is
assumed that the results of that other function call should be passed in
as that argument to the original function.

``` r
data_provider <- function() { # do something to return data... }

transformer <- function(data_provider) { do_something_to(data_provider) }
```

Above, the results of `data_provider` would be passed to `transformer`
since it takes an argument named `data_provider`. This allows one to
write normal, isolated, and testable functions that also define a DAG
without any extra code. Function dependencies are made clear from the
function signature itself easing understanding of a dataflow.

## Installation

``` r
# install.packages("devtools")
devtools::install_github("ejneer/dataflowr")
```

## Simple Example

Define functions that form a data flow to calculate the power to weight
ratio of some cars in `mtcars`.

``` r
library(dataflowr)

mtcars_data <- function(cyls) mtcars[mtcars$cyl %in% cyls, ]

horsepower <- function(mtcars_data) mtcars_data$hp

weight <- function(mtcars_data) mtcars_data$wt

power_to_weight <- function(horsepower, weight) horsepower / weight

execution_plan <- solve_dataflow("power_to_weight", rlang::current_env())
```

Looking at the AST of the new `power_to_weight` call shows what
`solve_dataflow` has done:

``` r
lobstr::ast(!!execution_plan$power_to_weight)
#> █─power_to_weight 
#> ├─horsepower = █─horsepower 
#> │              └─mtcars_data = █─mtcars_data 
#> │                              └─cyls = cyls 
#> └─weight = █─weight 
#>            └─mtcars_data = █─mtcars_data 
#>                            └─cyls = cyls
```

The arguments to `power_to_weight` were replaced with function calls
(represented by the blocks █ in the AST) of the same name since those
were function names in the given environment. Similarly, `horsepower`
and `weight` had their argument replaced with a function call. At the
beginning of the dataflow is `mtcars_data` whose only argument is *not*
named the same as a function, so it is left alone as a symbol.

At this point none of these functions have actually been executed, only
the order in which they would need to be executed has been resolved in
the returned environment (hence the name `execution_plan`). An
identically named version of every function and non-function argument
involved in the dataflow has been created in `execution_plan`, as a call
or symbol object respectively.

``` r
ls(execution_plan)
#> [1] "cyls"            "horsepower"      "mtcars_data"     "power_to_weight"
#> [5] "weight"

execution_plan$power_to_weight
#> power_to_weight(horsepower = horsepower(mtcars_data = mtcars_data(cyls = cyls)), 
#>     weight = weight(mtcars_data = mtcars_data(cyls = cyls)))

typeof(execution_plan$power_to_weight)
#> [1] "language"

execution_plan$horsepower
#> horsepower(mtcars_data = mtcars_data(cyls = cyls))

execution_plan$weight
#> weight(mtcars_data = mtcars_data(cyls = cyls))

execution_plan$mtcars_data
#> mtcars_data(cyls = cyls)

execution_plan$cyls
#> cyls

typeof(execution_plan$cyls)
#> [1] "symbol"
```

Note that these are not `function`s, but call (or “language”) objects
(except for `cyls`, a symbol). The definition of these functions does
not exist in the `execution_plan` environment so it is not of much use
on its own. The second argument to `solve_dataflow`, `envir`, becomes
the parent of `execution_plan`. To actually execute a call object in the
`execution_plan`, we can `eval` it, and when R tries to `eval` calls for
functions that don’t exist in the current environment, it will search
the parent environment where it will find function definitions in this
case.

We would also still need to provide a definition for data that isn’t a
function call, like `cyls` here. This is easy enough, as variable
bindings may be passed in a list to `eval`.

``` r
eval(execution_plan$power_to_weight, list(cyls = 4))
#>  [1] 40.08621 19.43574 30.15873 30.00000 32.19814 35.42234 39.35091 34.10853
#>  [9] 42.52336 74.68605 39.20863
```

To check ourselves:

``` r
mtcars[mtcars$cyl == 4, ]$hp / mtcars[mtcars$cyl == 4, ]$wt
#>  [1] 40.08621 19.43574 30.15873 30.00000 32.19814 35.42234 39.35091 34.10853
#>  [9] 42.52336 74.68605 39.20863
```

### Repeated Function Calls

You may have noticed that in the dataflow for `power_to_weight`,
`mtcars_data` executes more than once. This doesn’t matter much if
functions return results quickly, as they did in the simple example.
However, if a function is doing something time-consuming (e.g. a heavy
calculation or database query) this may lead to poor performance.

``` r
# with fast return
bench::bench_time(eval(execution_plan$power_to_weight, list(cyls = 4)))
#> process    real 
#>   107µs   106µs

# redefine mtcars_data to take a noticeable amount of time
mtcars_data <- function(cyls) {
  Sys.sleep(1)
  mtcars[mtcars$cyl %in% cyls, ]
}

bench::bench_time(eval(execution_plan$power_to_weight, list(cyls = 4)))
#> process    real 
#>   706µs   1.97s
```

Given that the `execution_plan` only knows how to call functions and not
their definitions, we can treat this as an orthogonal problem to the
dataflow. For example, function results may be cached in
`execution_plan`’s parent such that any function calls only happen once
for a given set of arguments.

``` r
mtcars_data <- memoise::memoise(mtcars_data)

bench::bench_time(eval(execution_plan$power_to_weight, list(cyls = 4)))
#> process    real 
#> 78.58ms   1.06s
```

Now the total dataflow takes roughly half as much time as before since
`mtcars_data` only gets called once instead of twice.
