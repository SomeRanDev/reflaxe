// =======================================================
// * UnnecessaryBlockRemover
// =======================================================

package reflaxe.preprocessors.implementations;

#if (macro || reflaxe_runtime)

import reflaxe.helpers.Context;
import haxe.macro.Type;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

/**
	Removes unnecessary variable aliases.
**/
class RemoveLocalVariableAliasesImpl {
	public static function process(el: Array<TypedExpr>): Array<TypedExpr> {
		final uvar = new RemoveLocalVariableAliasesImpl(el);
		return uvar.removeAliases();
	}

	// ---

	var el: Array<TypedExpr>;
	var parent: Null<RemoveLocalVariableAliasesImpl>;
	var aliases: Map<Int, TypedExpr>;

	public function new(el: Array<TypedExpr>, parent: Null<RemoveLocalVariableAliasesImpl> = null) {
		this.el = el;
		this.parent = parent;
		aliases = [];
	}

	/**
		Types that "copy" (like primitives) should not have aliases erased.
	**/
	function isCopyType(t: Type): Bool {
		final innerType = Context.followWithAbstracts(t);
		return switch(innerType) {
			case TAbstract(_.get() => abs, []): abs.hasMeta(":runtimeValue");
			case _ if(innerType.getMeta().maybeHas(":copyValue")): true;
			case _ if(innerType.isString()): true;
			case _: false;
		}
	}

	function removeAliases(): Array<TypedExpr> {
		final result: Array<TypedExpr> = [];
		for(expr in el) {
			final skipExpr = switch(expr.expr) {
				case TVar(declTVar, ogVarExpr) if(ogVarExpr != null && !isCopyType(declTVar.t)): {
					switch(ogVarExpr.unwrapUnsafeCasts().expr) {
						case TLocal(tvar): {
							var skip = false;
							// If both variable declarations have the same type, it's okay we ignored unsafe casts
							if(declTVar.t.equals(tvar.t)) {
								// might be worth keeping alias if the alias name is significantly smaller?
								final ogNameLen = tvar.name.length;
								final aliasNameLen = declTVar.name.length;
								if(ogNameLen <= aliasNameLen + 10) {
									final newVarExpr = if(aliases.exists(tvar.id)) {
										aliases.get(tvar.id).trustMe();
									} else {
										ogVarExpr.trustMe();
									}
									aliases.set(declTVar.id, newVarExpr);
									skip = true;
								}
							}
							skip; // skip if alias set
						}
						case _: false;
					}
				}
				case TBlock(blockExprs): {
					result.push(expr.copy(TBlock(process(blockExprs))));
					true; // skip since we supplied our own version of TBlock
				}
				case _: false;
			}

			if(!skipExpr) {
				result.push(expr);
			}
		}

		return result.map(replaceAliases);
	}

	function replaceAliases(e: TypedExpr): TypedExpr {
		switch(e.expr) {
			case TLocal(tvar): {
				final newExpr = aliases.get(tvar.id);
				if(newExpr != null) {
					return newExpr;
				}
			}
			case _:
		}
		return haxe.macro.TypedExprTools.map(e, replaceAliases);
	}
}

#end
