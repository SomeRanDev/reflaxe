package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class EnumOptionData {
	public var enumType(default, null): EnumType;
	public var field(default, null): EnumField;

	public var name(default, null): String;
	public var args(default, null): Array<EnumOptionArg>;

	public function new(enumType: EnumType, field: EnumField, name: String) {
		this.enumType = enumType;
		this.field = field;

		this.name = name;
		this.args = [];
	}

	public function addArg(arg: EnumOptionArg) {
		this.args.push(arg);
	}
}

#end
