package;

#if macro

import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.ReflectCompiler;
import reflaxe.BaseCompiler;

import reflaxe.helpers.OperatorHelper;
using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;

import reflaxe.input.ClassModifier;

class TestCompiler extends BaseCompiler {
	public static function Start() {
		ReflectCompiler.AddCompiler(new TestCompiler(), {
			fileOutputExtension: ".testout",
			outputDirDefineName: "testoutput",
			fileOutputType: FilePerModule,
			ignoreTypes: [],
			targetCodeInjectionName: "__testscript__",
			ignoreBodilessFunctions: true,
			smartDCE: true
		});

		ClassModifier.mod("MyClass", "testMod", macro {
			return 9999;
		});
	}

	public function compileClassImpl(classType: ClassType, varFields: ClassFieldVars, funcFields: ClassFieldFuncs): Null<String> {
		var decl = "class " + classType.getNameOrNative() + ":\n";

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

		var funcString = "";
		for(ff in funcFields) {
			final field = ff.field;
			final tfunc = ff.tfunc;
			final funcHeader = (ff.isStatic ? "static " : "") + "func " + field.getNameOrNative() + "(" + tfunc.args.map(a -> a.v.getNameOrNative()).join(", ") + "):\n";
			funcString += (funcHeader + compileClassFuncExpr(tfunc.expr).tab()).tab() + "\n\n";
		}

		final body = (varString.length > 0 ? varString + "\n" : "") + funcString;
		return decl + (body.length > 0 ? body : "\tpass");
	}

	public function compileEnumImpl(enumType: EnumType, constructs:Map<String, haxe.macro.EnumField>): Null<String> {
		return null;
	}

	public function compileExpressionImpl(expr: TypedExpr): Null<String> {
		var result = "";
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

	function binopToTestScript(op: Binop, e1: TypedExpr, e2: TypedExpr): String {
		final expr1 = compileExpression(e1);
		final expr2 = compileExpression(e2);
		final operatorStr = OperatorHelper.binopToString(op);
		return expr1 + " " + operatorStr + " " + expr2;
	}

	function unopToTestScript(op: Unop, e: TypedExpr, isPostfix: Bool): String {
		final expr = compileExpression(e);
		final operatorStr = OperatorHelper.unopToString(op);
		return isPostfix ? (expr + operatorStr) : (operatorStr + expr);
	}

	function fieldAccessToTestScript(e: TypedExpr, fa: FieldAccess): String {
		final expr = compileExpression(e);
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

	function moduleNameToTestScript(m: ModuleType): String {
		return m.getNameOrNative();
	}

	function typeNameToTestScript(t: Type, errorPos: Position): String {
		final ct = haxe.macro.TypeTools.toComplexType(t);
		final typeName = switch(ct) {
			case TPath(typePath): {
				// copy TypePath and ignore "params" since TestScript is typeless
				haxe.macro.ComplexTypeTools.toString(TPath({
					name: typePath.name,
					pack: typePath.pack,
					sub: typePath.sub,
					params: null
				}));
			}
			case _: null;
		}
		if(typeName == null) {
			err("Incomplete Feature: Cannot convert this type to TestScript at the moment.", errorPos);
		}
		return typeName;
	}
}

#end
