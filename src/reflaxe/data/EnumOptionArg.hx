package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class EnumOptionArg {
	public var optionData(default, null): EnumOptionData;

	public var type(default, null): Type;
	public var opt(default, null): Bool;
	public var name(default, null): String;

	public function new(optionData: EnumOptionData, type: Type, opt: Bool, name: String) {
		this.optionData = optionData;

		this.type = type;
		this.opt = opt;
		this.name = name;
	}
}

#end
