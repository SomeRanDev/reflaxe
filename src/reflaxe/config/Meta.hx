package reflaxe.config;

enum abstract Meta(String) from String to String {
	/**
		@:reassignOnSubfieldEdit(setterName: Ident, ...propertyNames: Ident)

		See `reflaxe/compiler/ReassignOnSubfieldEdit.hx`.
	**/
	var ReassignOnSubfieldEdit = ":reassignOnSubfieldEdit";

	/**
		If used on a type, temporary variables that might have been generated
		by the Haxe compiler (only used once) will be removed and inlined.

		See `reflaxe/preprocessors/implementations/RemoveTemporaryVariablesImpl.hx`.
	**/
	var AvoidTemporaries = ":avoidTemporaries";

	/**
		Indicates this type is "copied" instead of referenced when assigned.
		This is used by `RemoveLocalVariableAliases` to ensure only aliases
		that are references are removed.

		At the current moment this is only used by `RemoveLocalVariableAliases`.

		See `reflaxe/preprocessors/implementations/RemoveLocalVariableAliasesImpl.hx`.
	**/
	var CopyValue = ":copyValue";
}
