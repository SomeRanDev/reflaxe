package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassVarData {
	public var classType(default, null): ClassType;
	public var field(default, null): ClassField;

	public var isStatic(default, null): Bool;
	public var read(default, null): VarAccess;
	public var write(default, null): VarAccess;

	public function new(classType: ClassType, field: ClassField, isStatic: Bool, read: VarAccess, write: VarAccess) {
		this.classType = classType;
		this.field = field;

		this.isStatic = isStatic;
		this.read = read;
		this.write = write;
	}
}

#end
