package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.BaseCompiler;

class TargetCodeInjection {
	public static function checkTargetCodeInjection(injectFunctionName: String, expr: TypedExpr, compiler: DirectToStringCompiler): Null<String> {
		var arguments: Null<Array<TypedExpr>> = null;
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

		return if(callIdent == injectFunctionName && arguments != null) {
			if(arguments.length == 0) {
				#if eval
				Context.error(injectFunctionName + " requires at least one String argument.", expr.pos);
				#end
			}

			final injectionString: String = switch(arguments[0].expr) {
				case TConst(TString(s)): s;
				case _: {
					#if eval
					Context.error(injectFunctionName + " first parameter must be a constant String.", arguments[0].pos);
					#else
					"";
					#end
				}
			}

			// Initially fill all arguments as `null`.
			final injectionArguments = [ for(_ in 1...arguments.length) null ];

			// Use function so we only compile arguments that are used
			function getArg(i: Int) {
				return if(i < injectionArguments.length) {
					if(injectionArguments[i] == null) {
						final arg = compiler.compileExpressionForCodeInject(arguments[i + 1]);
						if(arg == null) {
							#if eval
							Context.error("Compiled expression resulted in nothing.", arguments[i].pos);
							#end
						} else {
							injectionArguments[i] = arg;
						}
					}
					injectionArguments[i];
				} else {
					null;
				}
			}

			// Find all instances of {NUMBER} and replace with argument if possible
			~/{(\d+)}/g.map(injectionString, function(ereg) {
				final num = Std.parseInt(ereg.matched(1));
				return (num != null ? getArg(num) : null) ?? ereg.matched(0);
			});
		} else {
			null;
		}
	}
}

#end
