package langcompiler;

#if (macro || LANG_runtime)

/**
	Used to generate LANGUAGE class source code from your intermediate data.
**/
function generateClass(c: AST.Class): Null<String> {
	// convert your intermediate `Class` type to LANGUAGE source code...
	return null;
}

/**
	Used to generate LANGUAGE enum source code from your intermediate data.
**/
function generateEnum(c: AST.Enum): Null<String> {
	// convert your intermediate `Enum` type to LANGUAGE source code...
	return null;
}

/**
	Convert `AST.Expr` to source code.
	This should be used in `generateClass` or `generateEnum`.
**/
function generateExpression(e: AST.Expr): Null<String> {
	return switch(e) {
		// Example for direclty injecting source code.
		case StringInject(code): code;

		// TODO: implement other cases that are created...
	}
}

#end
