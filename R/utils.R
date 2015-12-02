# Small functions that have no place elsewhere

# return 'budget' - 'spent', respecting the budget==0 special case
remainingbudget = function(budget, spent) {
  if (budget == 0) {  # the special case in which budget is unnamed vector with value 0.
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

deepcopy = function(obj) {
  unserialize(serialize(obj, NULL))
}

# call the backend function fname.<backendname> with arguments given in `...` or in
# optional argument 'arglist'.
callbackend = function(fname, backend, ...) {
  args = list(...)
  if (!is.null(args$arglist)) {
    args = args$argslist
  }
  do.call(paste(fname, backend, sep="."), args)
}

# write 'object' to file 'filename'. if filename ends with a '/', it is assumed
# to refer to a directory in which the file should be created using name 'basename', 
# postfixed with a possible postfix to avoid collision and '.rds'. 
writefile = function(filename, object, basename) {
  basepath = dirname(filename)
  if (basepath == "") {  # to ensure 'tempfile' doesnt give something in the root directory.
    basepath = "."
  }
  outfile = tempfile(paste0(basename, '_'), basepath, ".rds")
  saveRDS(object, outfile)
  
  if (substring(filename, nchar(filename)) == "/") {
    # TODO: if there is some way to atomically create a file only if it does not already exist,
    #  we could iteratively try to create <basename>_<n>.rds for n = 1, 2, 3, ...
    #  Instead, the current implementation just uses the tempfile() R function result.
    filename = outfile
  } else {
    file.rename(outfile, filename)
  }
  filename
}