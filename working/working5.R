


#install.packages("Rmpi", configure.args = c("--with-Rmpi-include=/usr/include/openmpi-x86_64/", "--with-Rmpi-libpath=/usr/lib64/openmpi/lib/",
#                   "--with-Rmpi-type=OPENMPI"))

# clean up after your mess
rm(list=objects()[grep('^(train|predict)Learner.[0-9]*$',objects())])
rm(list=objects()[objects() =="last.dump"])

reloadPckgs <- function(toReload) {
  lns <- loadedNamespaces()
  lnsAsPkg <- sub('.', '', lns, fixed=TRUE)
  pkgWithLibs = character(0)
  for (p in sapply(.dynLibs(), get, x='name')) {
    pkgWithLibs = c(pkgWithLibs, lns[lnsAsPkg == p])
  }
  delendum <- which(pkgWithLibs %in% names(toReload))
  if (length(delendum) == 0) {
    return()
  }
  firstPkgToUnload <- min(delendum)
  delendum <- pkgWithLibs[firstPkgToUnload:length(pkgWithLibs)]
  deleteQueue <- list()
  for (d in rev(delendum)) deleteQueue[[d]] = 1

  tried <- list()
  while (length(deleteQueue)) {
                                        #  print(names(deleteQueue))
    removing <- names(deleteQueue)[1]
    deps <- setdiff(getNamespaceUsers(removing), names(tried))
    for (dependency in deps) {
      deleteQueue[[dependency]] <- 1
    }
    deleteQueue[[removing]] <- NULL
    if (length(deps) == 0) {
      print(c("Removing", removing))
      tried[[removing]] <- 1
      pkgload::unload(find.package(removing))
    } else {
      deleteQueue[[removing]] <- 1
    }
  }
  lapply(toReload, devtools::load_all)
}

upstart <- function() {
  reloadPckgs(list(ParamHelpers="../../ParamHelpers", mlr="../../mlr",
                   smoof="../../smoof", mlrMBO="../../mlrMBO"))
  library('testthat')
  library(roxygen2)
  roxygenise('..')
  options(error=dump.frames)
  options(warn=1)
}


upstart()

devtools::load_all("..")



##
pid.task
##

## TODO: try to just set currentBudget to a large number

debugonce(amoptimize.ammbo)

resRand <- automlr(pid.task, budget=c(evals=300), backend="mbo", verbosity=3,
                   searchspace=list(mlrLearners$classif.ctree, mlrLearners$classif.rknn))

debugger()
q

plot(as.data.frame(amfinish(resRand)$opt.path)$y)


resRand <- automlr(pid.task, budget=c(evals=1), backend="random", verbosity=3,
                   max.walltime.overrun=10, max.learner.time=10,
                   searchspace=list(mlrLearners$classif.ctree, mlrLearners$classif.rknn))


configureMlr(on.error.dump = TRUE)

configureMlr(show.info=TRUE, on.error.dump = TRUE)
resRand <- automlr(pid.task, budget=c(walltime=20), backend="random", verbosity=3,
                   max.walltime.overrun=10, max.learner.time=10,
                   searchspace=list(mlrLearners$classif.ctree, mlrLearners$classif.rknn, mlrLearners$ampreproc))

names(mlrLearners)

as.data.frame(amfinish(resRand)$opt.path)

debugger(getOptPathEl(amfinish(resRand)$opt.path, 1)$extra$.dump[[1]][[1]])

automlr:::runWithTimeout

as.data.frame(amfinish(resRand)$opt.path)


tl <- makeRLearnerClassif('testlearner', par.set=makeParamSet(makeIntegerLearnerParam('testparam')), package=character(0))
tl$fix.factors.prediction=TRUE

trainLearner.testlearner = function(.learner, .task, .subset, .weights = NULL, testparam, ...) {
  print(colnames(getTaskData(.task)))
  testparam
}

predictLearner.testlearner = function(.learner, .model, .newdata, ...) {
  print(.model$learner.model)
  factor(rep(.model$task.desc$class.levels[1], nrow(.newdata)),
         levels=.model$task.desc$class.levels)
}

configureMlr(show.info=TRUE, on.error.dump = TRUE)

data = getTaskData(pid.task)
data[1, 1] = NA
pid.task2 = makeClassifTask(data=data, target=getTaskTargetNames(pid.task))


m <- train(setHyperPars(tl, testparam=2), pid.task)
predict(m, newdata=getTaskData(pid.task2))

tlw <- makePreprocWrapperAm(tl, ppa.nzv.cutoff.numeric=10, ppa.impute.numeric="remove.na", ppa.multivariate.trafo="ica")
mw <- train(setHyperPars(tlw, testparam=2), pid.task2)
predict(mw, newdata=getTaskData(pid.task2))


tlw2 <- makeFailImputationWrapper(tl)
mw2 <- train(setHyperPars(tlw2), pid.task2)
predict(mw2, newdata=getTaskData(pid.task2))


debugger(m$dump)
sapply(getTaskData(pid.task), var)


automlr:::trainLearner.PreprocWrapperAm()
debugonce(predictLearner.PreprocWrapperAm)

debugonce(trainLearner.PreprocWrapperAm)



##
configureMlr(show.info=TRUE, on.error.dump = TRUE)
resRand <- automlr(pid.task, budget=c(evals=3), backend="mbo", verbosity=3,
                   searchspace=mlrLightweight)

debug(makePreprocWrapperAm)


adf <- as.data.frame(amfinish(resRand)$opt.path)

names(adf)
adf[, c(1, 298:304)]

resRand2 <- automlr(resRand, budget=c(evals=1190), verbosity=5)

resRand$spent




resRand3 <- automlr(pid.task, budget=c(evals=3), backend="mbo", verbosity=3,
                   searchspace=mlrLightweight)



resRand3 <- automlr(pid.task, budget=c(evals=3), backend="mbo", verbosity=3,
                   searchspace=list(mlrLearners$classif.ctree, mlrLearners$classif.rknn))

debugonce(mlrMBO:::evalMBODesign.OptState)


##

getNativeSymbolInfo("lhs")
getNativeSymbolInfo("maximinLHS_C")

str(getCallingDLLe(getNamespace("lhs")))
getCallingDLLe(getNamespace("lhs"))$info
getCallingDLLe(getNamespace("lhs"))[[5]]



debugonce(lhs::maximinLHS)
.dynLibs(.dynLibs()[1:16!=8])

dyn.unload
devtools:::unload_dll
devtools:::load_dll
devtools:::loaded_dlls

##

recurseObj <- function(obj) {
  visitedList = list()
  visitedList[[capture.output(str(.GlobalEnv))]] = 1
  recurse <- function(obj, lvl) {

    indent = collapse(c("", rep("|", length(lvl))), sep="")
#    if (length(obj) < 10) {
#      out = capture.output(print(obj))
#      out = c(paste0(indent, out[out != ""]), "")
#      cat(collapse(out, sep="\n"))
#    }
    if (is.recursive(obj) && !is.atomic(obj)) {
      if (typeof(obj) == "...") {
        obj = evalq(list(...), list(`...`=obj))
      } else if (typeof(obj) == "closure") {
        obj = environment(obj)
      }
      if (typeof(obj) == "environment") {
        objRem <- obj
        attributes(objRem) <- NULL
        enname = capture.output(str(objRem))
        if (isNamespace(obj)) {
          position = collapse(lvl, sep=" -> ")
          catf("NAMESPACE %s%s", enname, position)
          return(NULL)
        }
        if (!is.null(visitedList[[enname]])) {
          return(NULL)
        }
        visitedList[enname] <<- 1
      }
      if (is.null(names(obj)) || any(names(obj) == "")) {
        for (i in seq_along(obj)) {
#          catf("%sentering: %i", indent, i)
          Recall(obj[[i]], lvl = c(lvl, i))
        }
      } else {
        for (i in names(obj)) {
#          catf("%sentering: %s", indent, i)
          Recall(obj[[i]], lvl = c(lvl, i))
        }
      }
    }
    for (an in names(attributes(obj))) {
      a = attr(obj, an)
      if (!is.atomic(a)) {
        Recall(a, lvl = c(lvl,an) )
      }
    }
  }
  recurse(obj, character(0))
}

recurseObj(lapply(objects(), get))
isNamespace(environment(lhs::maximinLHS))
