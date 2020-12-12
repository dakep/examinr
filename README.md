
# examinr R package

<!-- begin badges -->

<!-- [![CRAN\_Status\_Badge](https://www.r-pkg.org/badges/version/examinr)](https://CRAN.R-project.org/package=examinr) -->

![Lifecycle:
maturing](https://img.shields.io/badge/lifecycle-maturing-blue.svg)
![CRAN Status: not yet
released](https://img.shields.io/badge/CRAN-not%20yet%20released-red.svg)
[![Build
Status](https://travis-ci.com/dakep/examinr.svg?branch=main)](https://travis-ci.com/dakep/examinr)
<!-- end badges -->

Create gradable exams as interactive Shiny documents from R markdown
documents. Learners can attempt an exam one or more times, and each
attempt uses a (potentially) different random seed to generate the
question text and answers.

For a full list of features and to learn how to create your own exams,
visit the documentation at
[https://dakep.github.io/examinr](https://dakep.github.io/examinr/articles/examinr.html).

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

## Features to be added

The package is still in a development phase and some features are not
yet available, most notably the following:

  - File upload question.
  - Re-populate input values from client-side storage after page reload.
  - Multiple text inputs per text question.
  - Improved rendering of help pages.
  - Support of auto-grading for code exercises.

If you are looking for specific features which are not yet supported by
examinr and not yet requested, please create an
[issue](https://github.com/dakep/examinr/issues) or, even better, a
[pull request](https://github.com/dakep/examinr/pulls).

## Acknowledgments

Several features in examinr are inspired by the
[learnr](https://github.com/rstudio/learnr) package, in particular the
exercises.
