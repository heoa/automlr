# Small functions that have no place elsewhere

#################################
# syntactic sugar               #
#################################

`%+=%` = function(t, s) eval.parent(substitute(t <- t + s))
`%-=%` = function(t, m) eval.parent(substitute(t <- t - m))
`%c=%` = function(t, a) eval.parent(substitute(t <- c(t, a)))
`%union=%` = function(t, a) eval.parent(substitute(t <- union(t, a)))

#################################
# Budgeting                     #
#################################

# return 'budget' - 'spent', respecting the budget==0 special case
remainingbudget = function(budget, spent) {
  # the special case in which budget is unnamed vector with value 0.
  if (length(budget) == 1 && budget == 0) {
    return(0)
  }
  b = budget[names(spent)] - spent
  b[!is.na(b)]
}

# true if budget <= spent
stopcondition = function(budget, spent) {
  # if budget is 0, it may be an unnamed vector; we check for this separately
  any(remainingbudget(budget, spent) <= 0)
}

checkBudgetParam = function(budget) {
  if (!identical(budget, 0) && !identical(budget, 0L)) {
    assertNamed(budget)
    assertNumeric(budget, lower = 0, min.len = 1, max.len = 2)
    legalnames = c("walltime", "evals")
    budgetNamesOk = names(budget) %in% legalnames
    assert(all(budgetNamesOk))
  }
}

#################################
# List / Environment handling   #
#################################

deepcopy = function(obj) {
  unserialize(serialize(obj, NULL))
}

#################################
# File Handling                 #
#################################

checkfile = function(filename, basename) {
  assert(nchar(filename) > 0)
  if (substring(filename, 1, 1) != "/") {
    filename = paste0("./", filename)
  }
  givenAsDir = substring(filename, nchar(filename)) == "/"
  if (file.exists(paste0(filename, "/"))) {
    if (!givenAsDir) {
      stopf(paste0("Target file '%s' is a directory. To create a file inside ",
              " the directory, use '%s/' (trailing slash)."),
          filename, filename)
    }
    basepath = filename
    filename = tempfile(paste0(basename, "_"), basepath, ".rds")
    messagef("Will be saving to file %s", filename)
  } else {
    if (givenAsDir) {
      stopf(paste0("Directory '%s' does not exist. If you want to write to it ",
              "as a FILE, remove the trailing '/'."),
          filename)
    }
  }
  filename
}

# write 'object' to file 'filename'. if filename ends with a '/', it is assumed
# to refer to a directory in which the file should be created using name
# 'basename', postfixed with a possible postfix to avoid collision and '.rds'.
writefile = function(filename, object, basename) {
  basepath = dirname(filename)
  if (basepath == "") {
    # to ensure 'tempfile' doesnt give something in the root directory.
    basepath = "."
  }
  outfile = tempfile(paste0(basename, "_"), basepath, ".rds")
  saveRDS(object, outfile)
  file.rename(outfile, filename)
  invisible()
}

#################################
# Opt Path                      #
#################################

# append opt path op2 to opt path op1. This happens in-place.
appendOptPath = function(op1, op2) {
  # FIXME: check equality of par.set etc.
  for (vect in c("error.message", "exec.time", "dob", "eol", "extra")) {
    op1$env[[vect]] = c(op1$env[[vect]], op2$env[[vect]])
  }
  op1$env$path = rbind(op1$env$path, op2$env$path)
  NULL
}

# in-place subset an opt.path
subsetOptPath = function(op1, subset) {
  
  for (vect in c("error.message", "exec.time", "dob", "eol", "extra")) {
    op1$env[[vect]] = op1$env[[vect]][subset]
  }
  op1$env$path = op1$env$path[subset, , drop = FALSE]
  NULL
}

#################################
# Log Functions                 #
#################################

# similarly copied from mlr logFunOpt.R
logFunQuiet = function(learner, task, resampling, measures, par.set, control,
    opt.path, dob, x, y, remove.nas, stage, prev.stage) {
  
  if (stage == 1L) {
    list(start.time = Sys.time())
  }
}

#################################
# Fixes                         #
#################################

# make extractSubList commute with c():
# extractSubList(c(a, b), e) == c(extractSubList(a, e), extractSubList(b, e))
extractSubList = function(xs, element, element.value, simplify = TRUE,
    use.names = TRUE) {
  res = BBmisc::extractSubList(xs, element, element.value, simplify, use.names)
  if (simplify && is.list(res) && length(res) == 0) {
    # don't return an empty list
    logical(0)
  } else {
    res
  }
}

#################################
# Parameters & Expressions      #
#################################

removeAmlrfix = function(name) {
  sub("\\.AMLRFIX[0-9]+$", "", name)
}

# take a language object (call or expression), turn it into a call
deExpression = function(language) {
  if (is.null(language)) {
    return(NULL)
  }
  if (is.expression(language) && length(language) == 1) {
    language = language[[1]]
  }
  if (is.call(language)) {
    return(language)
  }
  substitute(eval(x), list(x = language))
}

replaceRequires = function(cprequires, substitution) {
  # bug in R core 'deparse' means we need to add parantheses in substitution.
  # if the `replaceRequires` worked without 'deparse', this would *still*
  # be necessary for irace, since irace deparses the requirements.
  substitution = lapply(substitution, function(q) substitute((q), list(q = q)))
  
  # what we are going to do is substitute the variable names with their new
  # prefixed versions.
  # HOWEVER: R uses different scoping for function calls than for variables.
  # therefore e.g.
  # > c <- 1
  # > c(c, c)
  # doesn't give an error. This is a pain when trying to do what I'm doing here.
  # So we will manually substitute all function calls with different names.
  #
  # the width.cutoff may be a problem? I wouldn't assume so if deparse keeps
  # function name and opening parenthesis on the same line.
  parsed = deparse(as.expression(cprequires),
      control = c("keepInteger", "keepNA"), width.cutoff = 500)
  funcallmatch = paste0("(?:((?:[[:alpha:]]|[.][._[:alpha:]])[._[:alnum:]]*)|",
      "(`)((?:[^`\\\\]|\\\\.)+`))(\\()")
  
  parsed = gsub(funcallmatch, "\\2.AUTOMLR_TEMP_\\1\\3\\4", parsed)
  #the following would be dumb:
  #parsed[1] = sub(".AUTOMLR_TEMP_expression(", "expression(", parsed[1],
  # fixed = TRUE) # NO!
  cprequires = asQuoted(paste(parsed, collapse = "\n"))
  # the following line is a bit of R magic. Use do.call, so that cprequires,
  # which is a 'quote' object, is expanded to its actual content. The
  # 'substitute' call will change all names of the old parameters to the new
  # parameters.
  cprequires = do.call(substitute, list(cprequires, substitution))
  
  funcallmatchReverse = paste0("(?:\\.AUTOMLR_TEMP_((?:[[:alpha:]]|",
      "[.][._[:alpha:]])[._[:alnum:]]*)|",
      "(`)\\.AUTOMLR_TEMP_((?:[^`\\\\]|\\\\.)+`))(\\()")
  parsed = deparse(cprequires,
      control = c("keepInteger", "keepNA"), width.cutoff = 500)
  parsed = gsub(funcallmatchReverse, "\\2\\1\\3\\4", parsed)
  deExpression(eval(asQuoted(paste(parsed, collapse = "\n"))))
}

remsrc = function(lang) {
  dumf = function() {}
  body(dumf) = lang
  body(removeSource(dumf))
}

langIdentical = function(l1, l2) {
  identical(remsrc(l1), remsrc(l2))
}

#################################
# OptPath Imputation            #
#################################

generateRealisticImputeVal = function(measure, learner, task) {
  naked = dropFeatures(task, getTaskFeatureNames(task))
  retval = bootstrapB632(learner, naked, iters = 100, show.info = FALSE)$aggr
  # and because convertYForTuner is retarded:
  retval * ifelse(measure$minimize, 1 , -1)
}

#################################
# Verbosity                     #
#################################

# whether to output optimization trace info
verbosity.traceout = function(verbosity) {
  verbosity >= 1
}

#whether to output memory info
verbosity.memtraceout = function(verbosity) {
  verbosity >= 5
}

# whether to output detailed search space warnings
verbosity.sswarnings = function(verbosity) {
  verbosity >= 2
}

# whether to output learner warnings
verbosity.learnerwarnings = function(verbosity) {
  verbosity >= 3
}

# whether to give learner output
verbosity.learneroutput = function(verbosity) {
  verbosity >= 4
}

# stop on learner error
verbosity.stoplearnerror = function(verbosity) {
  verbosity >= 6
}

getLearnerVerbosityOptions = function(verbosity) {
  config = list()
  # show.info is not used, but in case this changes at some point...
  config$show.info = verbosity.learneroutput(verbosity)
  config$on.learner.error = if (verbosity.stoplearnerror(verbosity))
        "stop"
      else if (verbosity.learnerwarnings(verbosity))
        "warn"
      else
        "quiet"
  config$on.learner.warning = if (verbosity.learnerwarnings(verbosity))
        "warn"
      else
        "quiet"
  config$show.learner.output = verbosity.learneroutput(verbosity)
  config
}

adjustLearnerVerbosity = function(learner, verbosity) {
  config = getLLConfig(learner)
  config = insert(config, getLearnerVerbosityOptions(verbosity))
  setLLConfig(learner, config)
}

#################################
# Learner Config                #
#################################

# getLearnerOptions without polluting the result with getMlrOptions()
getLLConfig = function(learner) {
  if (inherits(learner, "BaseWrapper")) {
    getLLConfig(learner$next.learner)
  } else {
    as.list(learner$config)
  }
}

# setLearnerOptions, basically
setLLConfig = function(learner, config) {
  if (identical(getLLConfig(learner), config)) {
    # avoid too much copy-on-write action for nothing
    learner
  } else {
    (function(l) {
        if (inherits(l, "BaseWrapper")) {
          l$next.learner = Recall(l$next.learner)
        } else {
          l$config = config
        }
        l
      })(learner)
  }
}

#################################
# Resampling Info               #
#################################

# return the value of `varname` within the function named `fname`. Use the most
# recent invocation of `fname` if names collide.
# Returns NULL if the function was not found.
getFrameVar = function(fname, varname) {
  # can not call getFrameNo, because then the last call will be in the list also.
  calls = sys.calls()
  calls[[length(calls) - 1]] = NULL
  callnames = sapply(calls,
      function(x) try(as.character(x[[1]]), silent = TRUE))
  frameno = tail(which(callnames == fname), n = 1)
  if (length(frameno) < 1) {
    return(NULL)
  }
  sys.frame(frameno)[[varname]]
}

getFrameNo = function(fname, getAll = FALSE) {
  calls = sys.calls()
  calls[[length(calls) - 1]] = NULL
  callnames = sapply(calls,
      function(x) try(as.character(x[[1]]), silent = TRUE))
  if (getAll) {
    which(callnames == fname)
  } else {
    tail(which(callnames == fname), n = 1)
  }
}

# assign the value of `varname` within the function named `fname`. Use the most
# recent invocation of `fname` if names collide.
# Returns TRUE if successful, FALSE if the function `fname` was not in the call
# stack.
assignFrameVar = function(fname, varname, value) {
  calls = sys.calls()
  calls[[length(calls) - 1]] = NULL
  callnames = sapply(calls,
      function(x) try(as.character(x[[1]]), silent = TRUE))
  frameno = tail(which(callnames == fname), n = 1)
  if (length(frameno) < 1) {
    return(FALSE)
  }
  assign(varname, value, sys.frame(frameno))
  TRUE
}

getResampleFrameNo = function() {
  resFrame = c(getFrameNo("resample"), getFrameNo("resample.fun"))
  if (length(resFrame) < 1) {
    return(NULL)
  }
  resFrame = min(resFrame)
  tpFrame = c(getFrameNo("train", TRUE), getFrameNo("predict", TRUE))
  if (length(tpFrame) < 1) {
    return(NULL)
  }
  # smallest 'train' or 'predict' frame greater than the 'resample' frame:
  tpFrame = sort(tpFrame)
  tpFrame[tpFrame > resFrame][1] - 2
}

isInsideResampling = function() {
  (length(c(getFrameNo('resample'), getFrameNo("resample.fun")) < 1) ||
        !is.null(getResampleIter()))
}

getResampleIter = function() {
  frameno = getResampleFrameNo()
  if (length(frameno) < 1) {
    return(NULL)
  }
  sys.frame(frameno)[['i']]
}

setResampleUID = function() {
  frameno = min(c(getFrameNo('resample'), getFrameNo("resample.fun")))
  uid = stats::runif(1)
  assign('$UID$', uid, envir=sys.frame(frameno))
  uid
}

getResampleUID = function() {
  frameno = min(c(getFrameNo('resample'), getFrameNo("resample.fun")))
  sys.frame(frameno)[['$UID$']]
}

getResampleMaxIters = function() {
  frameno = getResampleFrameNo()
  if (length(frameno) < 1) {
    return(NULL)
  }
  sys.frame(frameno)[['rin']]$desc$iters
}

# test whether mlr parallelizes resample() calls. This does NOT entail that
# isInsideResampling()!
isResampleParallel = function() {
  pmlevel = parallelGetOptions()$level
  !is.null(pmlevel) && pmlevel == "mlr.resample"
}

isFirstResampleIter = function() {
  rin = getResampleIter()
  if (is.null(rin)) {
    stop("'doResampleIteration' not found in call stack when it was expected.")
  }
  rin == 1
}

#################################
# AssignInNamespace             #
#################################

# assign functions in locked namespaces. This is the same mechanism that R
# trace() uses.
myAssignInNamespace = function(what, value, ns) {
  w = options("warn")
  on.exit(options(w))
  options(warn = -1)
  where = asNamespace(ns)
  if (bindingIsLocked(what, where)) {
    unlockBinding(what, where)
    assign(what, value, where)
    lockBinding(what, where)
  } else {
    assign(what, value, where)
  }
}

#################################
# Generics                      #
#################################

#' @title Retrieve a suggested search space of the given learner
#' 
#' @description
#' Learners created with \code{\link{buildLearners}} have a \code{$searchspace}
#' slot that can be accessed with this function.
#' 
#' @param learner [\code{Learner}]\cr
#'   Learner
#' @export
getSearchspace = function(learner) {
  UseMethod("getSearchspace")
}

#' @export
getSearchspace.BaseWrapper = function(learner) {
  getSearchspace(learner$next.learner)
}

#' @export
getSearchspace.automlrWrappedLearner = function(learner) {
  getSearchspace(learner$learner)
}

#################################
# RNG                           #
#################################

setSeed = function(seed) {
  if (!exists(".Random.seed", .GlobalEnv)) {
    set.seed(NULL)
  }
  assign(".Random.seed", seed, envir = .GlobalEnv)
}

getSeed = function() {
  if (!exists(".Random.seed", .GlobalEnv)) {
    set.seed(NULL)
  }
  get(".Random.seed", .GlobalEnv)
}

#################################
# Learner Wrapping              #
#################################

# make a copy of paramSet that has all 'when' attributes set to 'train'. 
makeAllTrainPars = function(paramSet) {
  paramSet$pars = lapply(paramSet$pars, function(x) {
        x$when = "train"
        x
      })
  paramSet
}

# Wrap a learner; mlr doesn't export this, but the following works better than
# the mlr BaseWrapper cruft anyways.

wrapLearner = function(cl, short.name, name, learner,
    type = learner$type,
    properties = getLearnerProperties(learner),
    par.set = makeAllTrainPars(getParamSet(learner)),
    par.vals = getHyperPars(learner),
    config = getLLConfig(learner)) {
  # finally, create the learner object that will be returned!
  constructor = switch(type,
      classif = makeRLearnerClassif,
      regr = makeRLearnerRegr,
      surv = makeRLearnerSurv,
      multilabel = makeRLearnerMultilabel,
      stopf("Task type '%s' not supported.", type))
  wrapper = constructor(
      cl = cl,
      short.name = short.name,
      name = name,
      properties = properties,
      par.set = par.set,
      par.vals = par.vals,
      package = "automlr")
  wrapper$fix.factors.prediction = FALSE

  
  wrapper$learner = removeHyperPars(learner,
      intersect(names2(getHyperPars(learner)), getParamIds(par.set)))
  wrapper$config = config
  wclass = class(wrapper)
  clpos = which(wclass == cl)
  assert(length(clpos) == 1)
  class(wrapper) = c(wclass[seq_len(clpos)], "automlrWrappedLearner",
      wclass[-seq_len(clpos)])
  setPredictType(wrapper, learner$predict.type)
}

#' @export
trainLearner.automlrWrappedLearner = function(.learner, .task, .subset,
    .weights = NULL, ...) {

  # would be nice to set hyperpars of learner here, but that squares with
  # amexowrapper.

  learner = .learner$learner
  # set the mlr $config of the learner to the config of the .learner
  # also we want errors to be thrown as usual 
  learner = setLLConfig(learner, insert(getLLConfig(.learner),
          list(on.learner.error = "stop", on.learner.warning = "warn")))

  # we want errors to be thrown here, but ModelMultiplexer doesn't keep 
  # options for further down. FIXME: report this
  oldMlrOptions = getMlrOptions()
  on.exit(do.call(configureMlr, oldMlrOptions), add = TRUE)
  do.call(configureMlr, insert(oldMlrOptions,
          list(show.info = TRUE,
              on.learner.error = "stop",
              on.learner.warning = "warn",
              show.learner.output = TRUE)))

  train(learner, task = .task, subset = .subset, weights = .weights)
}

#' @export
predictLearner.automlrWrappedLearner = function(.learner, .model, .newdata,
    ...) {
  # we can't just call predictLearner() here, unless we also wrap the whole
  # setHyperPars machinery, for which we would also need to be more diligent
  # setting the LearnerParam$when = train / test value.
  # The learner.model we are given is just an mlr WrappedModel that we can use
  # predict on.
  oldMlrOptions = getMlrOptions()
  on.exit(do.call(configureMlr, oldMlrOptions), add = TRUE)
  do.call(configureMlr, insert(oldMlrOptions,
          list(show.info = TRUE,
              on.learner.error = "stop",
              on.learner.warning = "warn",
              show.learner.output = TRUE)))
  getPredictionResponse(stats::predict(.model$learner.model,
          newdata = .newdata))
}





