package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.BaseCompiler;

class TargetCodeInjection {
	public static function checkTargetCodeInjection(injectFunctionName: String, expr: TypedExpr, compiler: BaseCompiler): Null<String> {
		var arguments: Array<TypedExpr>;
		final callIdent = switch(expr.expr) {
			case TCall(e, el): {
				switch(e.expr) {
					case TIdent(id): {
						arguments = el;
						id;
					}
					case _: null;
				}
			}
			case _: null;
		}

		return if(callIdent == injectFunctionName) {
			if(arguments.length == 0) {
				Context.error(injectFunctionName + " requires at least one String argument.", expr.pos);
			}

			final injectionString = switch(arguments[0].expr) {
				case TConst(TString(s)): s;
				case _: {
					Context.error(injectFunctionName + " first parameter must be a constant String.", arguments[0].pos);
				}
			}

			final injectionArguments = [];
			for(i in 1...arguments.length) {
				final arg = compiler.compileExpression(arguments[i]);
				if(arg == null) {
					Context.error("Compiled expression resulted in nothing.", arguments[i].pos);
				}
				injectionArguments.push(arg);
			}

			final split = injectionString.split("{}");
			var result = split[0];
			for(i in 1...split.length) {
				final splitter = if(i <= injectionArguments.length) {
					injectionArguments[i - 1];
				} else {
					"{}";
				}
				result += splitter + split[i];
			}

			result;
		} else {
			null;
		}
	}
}

#end
