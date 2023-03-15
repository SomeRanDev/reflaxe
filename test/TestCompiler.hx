package;

// Your compiler can be made to only exist at compile-time, but it's up to you!
#if macro

// Import relevant Haxe macro types.
import haxe.macro.Expr;
import haxe.macro.Type;

// Required Reflaxe types.
import reflaxe.ReflectCompiler;
import reflaxe.BaseCompiler;

// Reflaxe has a ton of "helper" classes with static extensions.
// A few are used here.
import reflaxe.helpers.OperatorHelper;
using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;

// This is a tool built into Reflaxe for modifying functions
// before typing using @:build macros. 
import reflaxe.input.ClassModifier;

class TestCompiler extends BaseCompiler {
	
	// This is the initialization macro used to make the compiler work!
	// It can be a static function in any class, but we place it in
	// the "TestCompiler" class for convenience. 
	//
	// Use `--macro TestCompiler.Start()` in your hxml to run!
	public static function Start() {

		// Pass an instance to `reflaxe.ReflectCompiler` using AddCompiler to activate it.
		// There's a ton of options that can be used.
		// Visit the reflaxe/BaseCompiler.hx file to view all of them + descriptions.
		ReflectCompiler.AddCompiler(new TestCompiler(), {
			fileOutputExtension: ".testout",
			outputDirDefineName: "testoutput",
			fileOutputType: FilePerModule,
			ignoreTypes: [],
			targetCodeInjectionName: "__testscript__",
			ignoreBodilessFunctions: true,
			smartDCE: true
		});

		// Example of ClassModifier
		// Modifies MyClass.testMod to return 9999.
		ClassModifier.mod("MyClass", "testMod", macro {
			return 9999;
		});
	}

	// This is the function from the BaseCompiler to override to compile Haxe classes.
	// Given the haxe.macro.ClassType and its variables and fields, return the output String.
	// If `null` is returned, the class is ignored and nothing is compiled for it.
	//
	// https://api.haxe.org/haxe/macro/ClassType.html
	public function compileClassImpl(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String> {
		// `getNameOrNative` is from `reflaxe.helpers.NameMetaHelper`.
		// Works with any object that matches { name: String, meta: MetaAccess }
		// Returns the value provided in `@:native` if that meta exists, and `name` otherwise.
		var decl = "class " + classType.getNameOrNative() + ":\n";

		// Iterate through the variables and compile them.
		var varString = "";
		for(vf in varFields) {
			final field = vf.field;
			final variableDeclaration = (vf.isStatic ? "static " : "") + "var " + field.getNameOrNative();
			final testScriptVal = if(field.expr() != null) {
				" = " + compileClassVarExpr(field.expr());
			} else {
				"";
			}
			varString += (variableDeclaration + testScriptVal).tab() + "\n";
		}

		// Iterate through the functions and compile them.
		var funcString = "";
		for(ff in funcFields) {
			final field = ff.field;
			final tfunc = ff.tfunc;
			final funcHeader = (ff.isStatic ? "static " : "") + "func " + field.getNameOrNative() + "(" + tfunc.args.map(a -> a.v.getNameOrNative()).join(", ") + "):\n";
			funcString += (funcHeader + compileClassFuncExpr(tfunc.expr).tab()).tab() + "\n\n";
		}

		// Combine all the compiled content together and return it.
		final body = (varString.length > 0 ? varString + "\n" : "") + funcString;
		return decl + (body.length > 0 ? body : "\tpass");
	}

	// Works just like `compileClassImpl`, but for Haxe enums.
	// Since we're returning `null` here, all Haxe enums are ignored.
	//
	// https://api.haxe.org/haxe/macro/EnumType.html
	public function compileEnumImpl(enumType: EnumType, constructs: EnumOptions): Null<String> {
		return null;
	}

	// This is the final required function.
	// It compiles the expressions generated from Haxe.
	//
	// PLEASE NOTE: to recusively compile sub-expressions, use "compileExpression".
	// That function handles optimizations and automated Reflaxe features
	// before finally passing the `TypedExpr` to "compileExpressionImpl".
	//
	// https://api.haxe.org/haxe/macro/TypedExpr.html
	public function compileExpressionImpl(expr: TypedExpr): Null<String> {
		var result = "";

		// Compiling the `TypedExpr` is simple. Check the `TypedExprDef` and act accordingly.
		// https://api.haxe.org/haxe/macro/TypedExprDef.html
		switch(expr.expr) {
			case TConst(constant): {
				result = constantToTestScript(constant);
			}
			case TLocal(v): {
				result = v.getNameOrNative();
			}
			case TArray(e1, e2): {
				result = compileExpression(e1) + "[" + compileExpression(e2) + "]";
			}
			case TBinop(op, e1, e2): {
				result = binopToTestScript(op, e1, e2);
			}
			case TField(e, fa): {
				result = fieldAccessToTestScript(e, fa);
			}
			case TTypeExpr(m): {
				result = moduleNameToTestScript(m);
			}
			case TParenthesis(e): {
				result = "(" + compileExpression(e) + ")";
			}
			case TObjectDecl(fields): {
				result = "{\n";
				for(i in 0...fields.length) {
					final field = fields[i];
					result += "\t\"" + field.name + "\": " + compileExpression(field.expr) + (i == fields.length - 1 ? "," : "") + "\n"; 
				}
				result += "}";
			}
			case TArrayDecl(el): {
				result = "[" + el.map(e -> compileExpression(e)).join(", ") + "]";
			}
			case TCall(e, el): {
				result = compileExpression(e) + "(" + el.map(e -> compileExpression(e)).join(", ") + ")";
			}
			case TNew(classTypeRef, _, el): {
				final className = classTypeRef.get().getNameOrNative();
				result = className + ".new(" + el.map(e -> compileExpression(e)).join(", ") + ")";
			}
			case TUnop(op, postFix, e): {
				result = unopToTestScript(op, e, postFix);
			}
			case TFunction(tfunc): {
				result = "func(" + tfunc.args.map(a -> a.v.getNameOrNative() + (a.value != null ? compileExpression(a.value) : "")) + "):\n";
				result += toIndentedScope(tfunc.expr);
			}
			case TVar(tvar, expr): {
				result = "var " + tvar.getNameOrNative();
				if(expr != null) {
					result += " = " + compileExpression(expr);
				}
			}
			case TBlock(el): {
				result = "if true:\n";

				if(el.length > 0) {
					result += el.map(e -> {
						var content = compileExpression(e);
						compileExpression(e).tab();
					}).join("\n");
				} else {
					result += "\tpass";
				}
			}
			case TFor(tvar, iterExpr, blockExpr): {
				result = "for " + tvar.getNameOrNative() + " in " + compileExpression(iterExpr) + ":\n";
				result += toIndentedScope(blockExpr);
			}
			case TIf(econd, ifExpr, elseExpr): {
				result = "if " + compileExpression(econd) + ":\n";
				result += toIndentedScope(ifExpr);
				if(elseExpr != null) {
					result += "\n";
					result += "else:\n";
					result += toIndentedScope(elseExpr);
				}
			}
			case TWhile(econd, blockExpr, normalWhile): {
				final cond = compileExpression(econd);
				if(normalWhile) {
					result = "while " + cond + ":\n";
					result += toIndentedScope(blockExpr);
				} else {
					result = "while true:\n";
					result += toIndentedScope(blockExpr);
					result += "\tif " + cond + ":\n";
					result += "\t\tbreak";
				}
			}
			case TSwitch(e, cases, edef): {
				result = "match " + compileExpression(e) + ":";
				for(c in cases) {
					result += "\n";
					result += "\t" + c.values.map(v -> compileExpression(v)).join(", ") + ":\n";
					result += toIndentedScope(c.expr).tab();
				}
				if(edef != null) {
					result += "\n";
					result += "\t_:\n";
					result += toIndentedScope(edef).tab();
				}
			}
			case TTry(e, catches): {
				// TODO
			}
			case TReturn(maybeExpr): {
				if(maybeExpr != null) {
					result = "return " + compileExpression(maybeExpr);
				} else {
					result = "return";
				}
			}
			case TBreak: {
				result = "break";
			}
			case TContinue: {
				result = "continue";
			}
			case TThrow(expr): {
				result = "throw " + compileExpression(expr);
			}
			case TCast(expr, maybeModuleType): {
				result = compileExpression(expr);
				if(maybeModuleType != null) {
					result += " as " + moduleNameToTestScript(maybeModuleType);
				}
			}
			case TMeta(metadataEntry, expr): {
				result = compileExpression(expr);
			}
			case TEnumParameter(expr, enumField, index): {
				result = Std.string(index + 2);
			}
			case TEnumIndex(expr): {
				result = "[1]";
			}
			case _: {}
		}
		return result;
	}

	// This is a special function written for the TestCompiler.
	// Helps organize how block scopes are compiled.
	// Highly recommend copy this and use it for yourself.
	//
	// Note the "tab" function is for Strings.
	// It comes from `reflaxe.helpers.SyntaxHelper`.
	// It simply adds tabs to every line in the String.
	function toIndentedScope(e: TypedExpr): String {
		return switch(e.expr) {
			case TBlock(el): {
				if(el.length > 0) {
					el.map(e -> compileExpression(e).tab()).join("\n");
				} else {
					"\tpass";
				}
			}
			case _: {
				compileExpression(e).tab();
			}
		}
	}

	function constantToTestScript(constant: TConstant): String {
		switch(constant) {
			case TInt(i): return Std.string(i);
			case TFloat(s): return s;
			case TString(s): return "\"" + s + "\"";
			case TBool(b): return b ? "true" : "false";
			case TNull: return "null";
			case TThis: return "self";
			case TSuper: return "super";
			case _: {}
		}
		return "";
	}

	// Compiles TConst
	function binopToTestScript(op: Binop, e1: TypedExpr, e2: TypedExpr): String {
		final expr1 = compileExpression(e1);
		final expr2 = compileExpression(e2);
		final operatorStr = OperatorHelper.binopToString(op);
		return expr1 + " " + operatorStr + " " + expr2;
	}

	// Compiles TUnop
	function unopToTestScript(op: Unop, e: TypedExpr, isPostfix: Bool): String {
		final expr = compileExpression(e);
		final operatorStr = OperatorHelper.unopToString(op);
		return isPostfix ? (expr + operatorStr) : (operatorStr + expr);
	}

	// Compiles TField
	function fieldAccessToTestScript(e: TypedExpr, fa: FieldAccess): String {
		final expr = compileExpression(e);

		// Each version of FieldAccess has different information.
		// In this case, we're simply trying to extract the name,
		// but you can compile different "accesses" differently.
		//
		// (For example, `obj.func` for instance access vs `obj::func` for static access).
		final fieldName = switch(fa) {
			case FInstance(_, _, classFieldRef): classFieldRef.get().name;
			case FStatic(_, classFieldRef): classFieldRef.get().name;
			case FAnon(classFieldRef): classFieldRef.get().name;
			case FDynamic(s): s;
			case FClosure(_, classFieldRef): classFieldRef.get().name;
			case FEnum(_, enumField): enumField.name;
		}
		return expr + "." + fieldName;
	}

	// Used to compile types in TTypeExpr and TCast
	function moduleNameToTestScript(m: ModuleType): String {
		return m.getNameOrNative();
	}
}

#end
