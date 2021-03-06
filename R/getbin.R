getbin <- function(fnargs){
	CONTENTTYPE <- "binary/octet-stream";
	DISPOSITION <- 'rawdata.bin';

	mytempfile <- do.call(dogetbin, fnargs);

	if(!is.null(attr(mytempfile, "contenttype"))){
		CONTENTTYPE <- attr(mytempfile, "contenttype");	
	}	
	
	if(!is.null(attr(mytempfile, "filename"))){
		DISPOSITION <- attr(mytempfile, "filename");	
	}
	
	return(list(filename = mytempfile, type = CONTENTTYPE, disposition = DISPOSITION));
}

dogetbin <- function(`#dofn`, ...){
	
	#prepare
	mytempfile <- tempfile();
	
	# The code below works fine. However, hadley's method results in a smaller 'call' object for the 
	# resulting object.
	#
	# e1 <- new.env(parent = .GlobalEnv)
	# output <- eval(get("#dofn")(...), envir=e1);
	
	#build the function call and evaluate expressions at the very last moment.
	fnargs <- as.list(match.call(expand.dots=F)$...);
	argn <- lapply(names(fnargs), as.name);
	names(argn) <- names(fnargs);
	
	#insert expressions into call
	exprargs <- sapply(fnargs, is.expression);
	if(length(exprargs) > 0){
		expressioncalls <- lapply(fnargs[exprargs], "[[", 1);
		argn[names(fnargs[exprargs])] <- expressioncalls;
	}
	
	#call the new function
	if(is.character(`#dofn`)){
		mycall <- as.call(c(list(parse(text=`#dofn`)[[1]]), argn));
	} else {
		mycall <- as.call(c(list(as.name("FUN")), argn));
		fnargs <- c(fnargs, list("FUN" = `#dofn`));		
	}
	
	output <- eval(mycall, fnargs, globalenv());

	#write output
	if(!is.raw(output)){
		stop("/R/bin/ handler should only be used for functions that return raw vectors.");
	}
	
	#write raw vector to file.
	writeBin(as.vector(output), mytempfile);

	#the raw vector can have attributes 'contenttype' and 'filename'.
	if(!is.null(attr(output, "contenttype"))){
		attr(mytempfile, "contenttype") <- attr(output, "contenttype"); 
	}
	
	if(!is.null(attr(output, "filename"))){
		attr(mytempfile, "filename") <- attr(output, "filename"); 
	}
	return(mytempfile);	
}