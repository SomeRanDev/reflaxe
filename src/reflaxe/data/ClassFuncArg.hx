package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.input.ClassHierarchyTracker;

using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFuncArg {
	public var funcData(default, null): Null<ClassFuncData>;
	public var index(default, null): Int;

	public var type(default, null): Type;
	public var opt(default, null): Bool;
	public var name(default, null): String;
	public var expr(default, null): Null<TypedExpr>;
	public var tvar(default, null): Null<TVar>;

	public function new(index: Int, type: Type, opt: Bool, name: String, expr: Null<TypedExpr> = null, tvar: Null<TVar> = null) {
		this.index = index;

		this.type = type;
		this.opt = opt;
		this.name = name;
		this.expr = expr;
		this.tvar = tvar;
	}

	/**
		Assigning the `ClassFuncData` is delayed so the arguments
		can be passed first.
	**/
	public function setFuncData(funcData: ClassFuncData) {
		this.funcData = funcData;
	}

}

#end
