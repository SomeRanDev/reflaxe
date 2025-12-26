package reflaxe.data;

#if (macro || reflaxe_runtime)

import reflaxe.preprocessors.ExpressionPreprocessor;
import haxe.macro.Type;

using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFieldData {
	public final id: String;
	
	public final classType: ClassType;
	public final field: ClassField;

	public final isStatic: Bool;

	public var expr(default, null): Null<TypedExpr>;

	var variableUsageCount: Null<Map<Int, Int>>; // Not quite sure if its necessary here, but keep it :P

	public function new(id:String, classType: ClassType, field: ClassField, isStatic: Bool, expr:Null<TypedExpr> = null) {
		this.id = id;

		this.classType = classType;
		this.field = field;

		this.isStatic = isStatic;

		this.expr = expr;
	}

	/**
		Sets the typed expression.
		Invalidates any cached information regarding the old expression.
	**/
	public function setExpr(e: TypedExpr) {
		expr = e;

		// The expression changed, so the stored usage count data is now invalid.
		variableUsageCount = null;
	}

	/**
		Works the same as `setExpr`, but takes an array of expressions.

		If just one expression, it is used directly.
		Multiple are converted into a block expression.
	**/
	public function setExprList(expressions: Array<TypedExpr>) {
		if(expressions.length == 1) {
			setExpr(expressions[0].trustMe());
		} else if(expr != null) {
			// Retain the previous expression's Position and Type.
			setExpr(expr.copy(TBlock(expressions)));
		} else {
			throw "`expr` must not be `null` when using ClassFuncData.setExprList.";
		}
	}

	/**
		A map of the number of times a variable is used can optionally
		be provided for later reference.

		This is usually calculated using `EverythingIsExprSanitizer` prior
		to other optimizations. 
	**/
	public function setVariableUsageCount(usageMap: Map<Int, Int>) {
		variableUsageCount = usageMap;
	}

	/**
		Returns the variable usage count.
		If it has not been calculated yet, it is calculated here.
	**/
	public function getOrFindVariableUsageCount(): Map<Int, Int> {
		if(expr == null) {
			return [];
		}

		final map: Map<Int, Int> = [];
		function count(e: TypedExpr) {
			switch(e.expr) {
				case TVar(tvar, _): {
					map.set(tvar.id, 0);
				}
				case TLocal(tvar): {
					map.set(tvar.id, (map.get(tvar.id) ?? 0) + 1);
				}
				case _:
			}
			return haxe.macro.TypedExprTools.map(e, count);
		}
		count(expr);
		return variableUsageCount = map;
	}

	/**
		Applies preprocessors to the `expr`.
	**/
	public function applyPreprocessors(compiler: BaseCompiler, preprocessors: Array<ExpressionPreprocessor>) {
		for(processor in preprocessors) {
			processor.process(this, compiler);
		}
	}
}
#end
