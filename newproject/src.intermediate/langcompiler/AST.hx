package langcompiler;

#if (macro || LANG_runtime)

/**
	Stores intermediate data generated from the Haxe class AST.
	The information here will be used to generate the LANGUAGE files.
**/
class Class {
	// insert data relating to your target's class implementation...
}

/**
	Stores intermediate data generated from the Haxe enum AST.
	The information here will be used to generate the LANGUAGE files.
**/
class Enum {
	// insert data relating to your target's enum implementation...
}

/**
	A LANGUAGE-based expression AST that will be generated from Haxe typed expressions.
	The information here will be used to generate expression content in `Class` and `Enum`.
**/
enum Expr {
	// input your targets expression types....

	StringInject(code: String);
}

#end
