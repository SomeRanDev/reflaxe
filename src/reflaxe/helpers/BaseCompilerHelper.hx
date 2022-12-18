// =======================================================
// * BaseCompilerHelper
//
// Additional helper functions for the BaseCompiler.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import reflaxe.BaseCompiler;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using StringTools;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.NullableMetaAccessHelper;

class BaseCompilerHelper {
	public static function compileNativeFunctionCodeMeta(compiler: BaseCompiler, callExpr: TypedExpr, arguments: Array<TypedExpr>): Null<String> {
		final declaration = callExpr.getDeclarationMeta();
		if(declaration == null) {
			return null;
		}
		final meta = declaration.meta;
		if(meta.maybeHas(":nativeFunctionCode")) {
			final entry = meta.extract(":nativeFunctionCode")[0];
			if(entry.params == null || entry.params.length == 0) {
				Context.error("One string argument expected containing the native code.", entry.pos);
			}

			final code = switch(entry.params[0].expr) {
				case EConst(CString(s, _)): s;
				case _: Context.error("One string argument expected.", entry.pos);
			}

			final thisExpr = declaration.thisExpr != null ? compiler.compileExpression(declaration.thisExpr) : null;
			final argExprs = arguments.map(compiler.compileExpression);

			var result = code;

			if(code.contains("{this}")) {
				if(thisExpr == null) {
					if(declaration.thisExpr == null) {
						Context.error("Cannot use {this} on @:nativeFunctionCode meta for constructors.", entry.pos);
					} else {
						compiler.onExpressionUnsuccessful(callExpr.pos);
					}
				} else {
					result = result.replace("{this}", thisExpr);
				}
			}

			for(i in 0...argExprs.length) {
				final key = "{arg" + i + "}";
				if(code.contains(key)) {
					if(argExprs[i] == null) {
						compiler.onExpressionUnsuccessful(arguments[i].pos);
					} else {
						result = result.replace(key, argExprs[i]);
					}
				}
			}

			return result;
		}

		return null;
	}
}

#end
