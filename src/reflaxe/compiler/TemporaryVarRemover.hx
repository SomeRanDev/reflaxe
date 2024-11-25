package reflaxe.compiler;

import haxe.macro.Type;

import reflaxe.config.Meta;

using StringTools;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypedExprHelper;

/**
	Represents the different modes `TemporaryVarRemover` can be set to.
**/
enum TemporaryVarRemoverMode {
	/**
		Only variables used once and assigned from class fields are purged.

		```haxe
		// This would be converted...
		{
			final sprite = object.sprite;
			sprite.expand(2.0);
		}

		// ... to this.
		{
			object.sprite.expand(2.0);
		}
		```
	**/
	OnlyFieldAccess;

	/**
		Any variable that is used once and name starts with "temp" will
		be removed.

		```haxe
		// This would be converted...
		{
			final tempVal = noise(23, 43);
			generate(tempVal);
		}

		// ... to this.
		{
			generate(noise(23, 43));
		}
		```
	**/
	AllTempVariables;

	/**
		All variables that are used once will be removed.

		```haxe
		// This would be converted...
		{
			final direction = 12.0 * (Math.PI / 180.0);
			final speed = 10.0;
			final x = Math.cos(direction);
			final y = Math.sin(direction);
			final sprite = object.sprite;
			sprite.move(x * speed, y * speed);
		}

		// ... to this.
		{
			final direction = 12.0 * (Math.PI / 180.0);
			final speed = 10.0;
			object.sprite.move(Math.cos(direction) * speed, Math.sin(direction) * speed);
		}
		```
	**/
	AllOneUseVariables;
}

class TemporaryVarRemover {
	/**
		The type of variables that are removed.
	**/
	public var mode(default, null): TemporaryVarRemoverMode;

	/**
		The original expression passed.
	**/
	var expr: TypedExpr;

	/**
		The original expression extracted as a TBlock list.
	**/
	var exprList: Array<TypedExpr>;

	/**
		The `TemporaryVarRemover` that created this instance.
	**/
	var parent: Null<TemporaryVarRemover>;

	/**
		A map of all the variables that are being removed.
	**/
	var tvarMap: Map<Int, TypedExpr> = [];

	/**
		A reference to a map that tracks the variable usage count.
		May not be available.
	**/
	var varUsageCount: Null<Map<Int, Int>>;

	/**
		Constructor.

		`varUsageCount` is an externally generated map containing the number of times
		a variable is used. The key is the `TVar` `id` and the value is the use count.
	**/
	public function new(mode: TemporaryVarRemoverMode, expr: TypedExpr, varUsageCount: Null<Map<Int, Int>> = null) {
		this.mode = mode;
		this.expr = expr;
		this.varUsageCount = varUsageCount;

		exprList = switch(expr.expr) {
			case TBlock(exprs): exprs.map(e -> e.copy());
			case _: [expr.copy()];
		}
	}

	/**
		Generate copy of `expr` with temporaries removed.
	**/
	public function fixTemporaries(): TypedExpr {
		function mapTypedExpr(mappedExpr, noReplacements): TypedExpr {
			switch(mappedExpr.expr) {
				case TLocal(v) if(!noReplacements): {
					final e = findReplacement(v.id);
					if(e != null) return e;
				}
				case TBlock(_): {
					final tvr = new TemporaryVarRemover(mode, mappedExpr, varUsageCount);
					tvr.parent = this;
					return tvr.fixTemporaries();
				}
				case _:
			}
			return haxe.macro.TypedExprTools.map(mappedExpr, e -> mapTypedExpr(e, noReplacements));
		}

		final result = [];

		var hasOverload = false;

		for(i in 0...exprList.length) {
			if(i < exprList.length - 1) {
				switch(exprList[i].expr) {
					case TVar(tvar, maybeExpr): {
						if(shouldRemoveVariable(tvar, maybeExpr)) {
							tvarMap.set(tvar.id, mapTypedExpr(maybeExpr.trustMe(), false));
							hasOverload = true;
							continue;
						}
					}
					case _:
				}
			}

			result.push(mapTypedExpr(exprList[i], parent == null && !hasOverload));
		}

		return expr.copy(TBlock(result));
	}

	/**
		Given the data from a `TVar` `TypedExpr`, returns `true` if the
		variable should be removed.
	**/
	function shouldRemoveVariable(tvar: TVar, maybeExpr: Null<TypedExpr>): Bool {
		if(getVariableUsageCount(tvar.id) >= 2) {
			return false;
		}

		return switch(mode) {
			case OnlyFieldAccess if(isField(maybeExpr)): {
				switch(tvar.t) {
					case TInst(clsRef, _): clsRef.get().hasMeta(Meta.AvoidTemporaries);
					case _: false;
				}
			}
			case AllTempVariables: tvar.name.startsWith("temp");
			case AllOneUseVariables: true;
			case _: false;
		}
	}

	/**
		Returns `true` if the expression is an identifier or field access.
	**/
	static function isField(expr: Null<TypedExpr>): Bool {
		if(expr == null) return false;

		return switch(expr.expr) {
			case TParenthesis(e): isField(e);
			case TField(_, _): true;
			case _: false;
		}
	}

	/**
		If the variable ID exists in the map for this instance of any of
		the parents, its expression will be returned. `null` otherwise.
	**/
	function findReplacement(variableId: Int): Null<TypedExpr> {
		if(tvarMap.exists(variableId)) {
			return tvarMap.get(variableId).trustMe();
		} else if(parent != null) {
			final e = parent.findReplacement(variableId);
			if(e != null) return e;
		}
		return null;
	}

	/**
		Returns the number of usages for the variable if possible.
	**/
	function getVariableUsageCount(variableId: Int): Int {
		return if(varUsageCount != null && varUsageCount.exists(variableId)) {
			varUsageCount.get(variableId) ?? 0;
		} else {
			0;
		}
	}
}
