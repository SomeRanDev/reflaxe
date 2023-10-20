package langcompiler;

// Make sure this code only exists at compile-time.
#if (macro || LANG_runtime)

// Import relevant Haxe macro types.
import haxe.macro.Type;

// Import Reflaxe types
import reflaxe.GenericCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.output.DataAndFileInfo;
import reflaxe.output.StringOrBytes;

/**
	The class used to compile the Haxe AST into your target language's code.

	This must extend from `GenericCompiler`.
**/
class Compiler extends GenericCompiler<AST.Class, AST.Enum, AST.Expr> {
	/**
		This is the function from the `GenericCompiler` to override to compile Haxe classes.
		Given the `haxe.macro.ClassType` and its variables and fields, extract data needed to generate your output.
		If `null` is returned, the class is ignored and nothing is compiled for it.

		https://api.haxe.org/haxe/macro/ClassType.html
	**/
	public function compileClassImpl(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<AST.Class> {
		// TODO: implement
		return null;
	}

	/**
		Works just like `compileClassImpl`, but for Haxe enums.
		Since we're returning `null` here, all Haxe enums are ignored.
		
		https://api.haxe.org/haxe/macro/EnumType.html
	**/
	public function compileEnumImpl(enumType: EnumType, constructs: Array<EnumOptionData>): Null<AST.Enum> {
		// TODO: implement
		return null;
	}

	/**
		This is the final required function.
		It compiles the expressions generated from Haxe.
		
		PLEASE NOTE: to recusively compile sub-expressions, use these functions from `GenericCompiler`:
		```haxe
		GenericCompiler.compileExpression(expr: TypedExpr): Null<AST.Expr>
		GenericCompiler.compileExpressionOrError(expr: TypedExpr): AST.Expr
		```
		
		https://api.haxe.org/haxe/macro/TypedExpr.html
	**/
	public function compileExpressionImpl(expr: TypedExpr, topLevel: Bool): Null<AST.Expr> {
		// TODO: implement
		return switch(expr.expr) {

			// Here's a very basic example of converting `untyped __LANG__("something")` into source code...
			case TCall({ expr: TIdent("__LANG__") }, [{ expr: TConst(TString(s)) }]): {
				return StringInject(s);
			}

			case _: null;
		}
	}

	/**
		This is used to configure what files are generated.
		Create an iterator to return the file data.

		NOTE: the `GenericCompiler` has fields containing the generated module types:
		```haxe
		var classes: Array<DataAndFileInfo<AST.Class>>;
		var enums: Array<DataAndFileInfo<AST.Enum>>;
		```
	**/
	public function generateOutputIterator(): Iterator<DataAndFileInfo<StringOrBytes>> {
		var index = 0;
		return {
			hasNext: function() {
				return index < (classes.length + enums.length);
			},
			next: function() {
				return if(index < classes.length) {
					final cls = classes[index++];
					cls.withOutput(Generator.generateClass(cls.data));
				} else {
					final enm = enums[(index++) - classes.length];
					enm.withOutput(Generator.generateEnum(enm.data));
				}
			}
		}
	}
}

#end
