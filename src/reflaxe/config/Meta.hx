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

		See `reflaxe/compiler/TemporaryVarRemover.hx`.
	**/
	var AvoidTemporaries = ":avoid_temporaries";
}
