package reflaxe.config;

enum abstract Meta(String) from String to String {
	/**
		@:reassignOnSubfieldEdit(setterName: Ident, ...propertyNames: Ident)

		See `reflaxe/compiler/ReassignOnSubfieldEdit.hx`.
	**/
	var ReassignOnSubfieldEdit = ":reassignOnSubfieldEdit";
}
