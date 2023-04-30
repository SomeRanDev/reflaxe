package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFuncData {
	public var classType(default, null): ClassType;
	public var field(default, null): ClassField;

	public var isStatic(default, null): Bool;
	public var kind(default, null): MethodKind;

	public var ret(default, null): Type;
	public var args(default, null): Array<ClassFuncArg>;
	public var tfunc(default, null): Null<TFunc>;
	public var expr(default, null): Null<TypedExpr>;

	public function new(classType: ClassType, field: ClassField, isStatic: Bool, kind: MethodKind, ret: Type, args: Array<ClassFuncArg>, tfunc: Null<TFunc>, expr: Null<TypedExpr>) {
		this.classType = classType;
		this.field = field;

		this.isStatic = isStatic;
		this.kind = kind;

		this.ret = ret;
		this.args = args;
		this.tfunc = tfunc;
		this.expr = expr;
	}

	public function setExpr(e: TypedExpr) {
		expr = e;
	}
}

#end
