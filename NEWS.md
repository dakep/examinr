# Version 0.3.0

* Save R code chunks when submitting a section (without evaluation the code on the server).
  This prevents cases where users don't run the R code and hence no answer would be recorded.
* Enable code highlighting in server-rendered sections when using R code chunks (fenced within ```` ```{r ````).
* Make client-side attempt storage specific to the exam id and version.
* Better handling of cli-styled condition messages.
* Add shortcut for specifying exercise solution/setup chunks.
  Setting `exercise.solution=TRUE` is short for exercise code chunk label plus `-solution`.
  In the following exam, for example, the chunk *coding-exercise-solution* is taken as the solution to exercise chunk *coding-exercise:*

````md

```{r coding-exercise, exercise=TRUE, exercise.solution=TRUE}

```

```{r coding-exercise-solution, eval=FALSE}
# here is the solution code
```

````
