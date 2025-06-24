package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.BaseCompiler;

class TargetCodeInjection {
	/**
		Checks if the expression is an injection expression.
		If it is, returns the directly compiled code string.

		This only works with `DirectToStringCompiler`, see `checkTargetCodeInjectionGeneric` if using `GenericCompiler`.
	**/
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
				final num = num != null ? getArg(num) : null;
				return num ?? ereg.matched(0);
			});
		} else {
			null;
		}
	}

	/**
		Returns a mixed array of `String` and your custom expression type if the
		expression is an injection expression.
	**/
	public static function checkTargetCodeInjectionGeneric<A, B, ExpressionType, C, D>(injectFunctionName: String, expr: TypedExpr, compiler: GenericCompiler<A, B, ExpressionType, C, D>): Null<Array<haxe.ds.Either<String, ExpressionType>>> {
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

		if(callIdent != injectFunctionName || arguments == null) {
			return null;
		}

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
		final injectionArguments: Array<Null<ExpressionType>> = [ for(_ in 1...arguments.length) null ];

		// Use function so we only compile arguments that are used
		function getArg(i: Int): Null<ExpressionType> {
			return if(i < injectionArguments.length) {
				if(injectionArguments[i] == null) {
					final arg = compiler.compileExpression(arguments[i + 1]);
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

		final result = [];

		var lastMatchPosition: Null<{ pos: Int, len: Int }> = null;

		// Find all instances of {NUMBER} and replace with argument if possible
		~/{(\d+)}/g.map(injectionString, function(ereg) {

			final lastPos = lastMatchPosition == null ? 0 : lastMatchPosition.pos + lastMatchPosition.len;
			lastMatchPosition = ereg.matchedPos();
			if(lastMatchPosition.pos != lastPos) {
				result.push(haxe.ds.Either.Left(injectionString.substring(lastPos, lastMatchPosition.pos)));
			}

			final expressionIndex = Std.parseInt(ereg.matched(1));
			final expression = expressionIndex != null ? getArg(expressionIndex) : null;
			if(expression != null) {
				result.push(haxe.ds.Either.Right(expression));
			}

			return "";
		});

		if(lastMatchPosition != null) {
			result.push(haxe.ds.Either.Left(injectionString.substring(lastMatchPosition.pos + lastMatchPosition.len)));
		}

		return result;
	}
}

#end
