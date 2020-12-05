
# examinr R package

<!-- begin badges -->

![Lifecycle:
maturing](https://img.shields.io/badge/lifecycle-maturing-blue.svg)
![CRAN Status: not yet
released](https://img.shields.io/badge/CRAN-not%20yet%20released-red.svg)
<!-- [![CRAN\_Status\_Badge](https://www.r-pkg.org/badges/version/examinr)](https://CRAN.R-project.org/package=examinr) -->
[![Build
Status](https://travis-ci.com/dakep/examinr.svg?branch=main)](https://travis-ci.com/dakep/examinr)
<!-- end badges -->

Create gradable exams as interactive Shiny documents from R Markdown
documents. Learners can attempt an exam one or more times, and each
attempt uses specific random seed to generate the question text and
answers.

For a full list of features and to learn how to create your own exams,
visit the documentation at <https://dakep.github.io/examinr>.

## Installation

The package is still in development and not yet available on CRAN. You
can install it via

``` r
devtools::install_github("dakep/examinr")
```

## Highlights

  - Questions and text are rendered on-demand for each attempt:
      - Allows for user- and attempt-specific content (e.g., randomized
        values in questions and answers)
      - Questions are not sent to the user’s browser until they are
        allowed to see them
  - Support for different question types:
      - Simple text answers
      - R code exercises
      - Numeric answers (with auto-grading support)
      - Multiple-choice (with auto-grading support)
  - Users are authenticated via configurable authentication providers
  - Exams can be configured to show only one section at a time
  - Fine-grained control over attempts:
      - Control how many attempts each user gets
      - Configure exams to be only accessible after the opening time and
        until the closing time
      - Timed attempts where users are required to submit the exam
        within the specific time limits
      - Adjust the configuration for specific users
  - Support for message localization
  - Interfaces for grading (for instructors) and for accessing feedback
    (for users).
  - High-contrast theme and screen-reader friendly output

## Missing features

The package is still in a development phase and some features are not
yet available, most notably the following:

  - No authentication provider is available which requires users to log
    in on the exam page before accessing the exam. This may be useful in
    situations where RStudio Connect is not available or where users
    don’t have a user on the RStudio Connect installation
  - Reloading the page clears all input.
  - Only one input per text question. Allowing more than one input
    (e.g., for the lower and upper bounds of confidence intervals) is in
    the works.
  - Rendering of help pages is not very nice.
  - No auto-grading of code exercises.

If you are looking for specific features which are not yet supported by
examinr and not yet requested, please create an
[issues](https://github.com/dakep/examinr/issues) or, even better, a
[pull request](https://github.com/dakep/examinr/pulls).

## Acknowledgments

Many features in examinr are inspired from the
[learnr](https://github.com/rstudio/learnr) package, in particular the
exercises.
