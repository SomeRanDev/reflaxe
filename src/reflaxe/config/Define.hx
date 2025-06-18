package reflaxe.config;

enum abstract Define(String) from String to String {
	/**
		-D reflaxe.allow_rose

		Enables the "reassign on subfield edit" feature.
		This allows the `@:reassignOnSubfieldEdit` meta to be used.

		See `reflaxe/compiler/ReassignOnSubfieldEdit.hx`.
	**/
	var AllowROSE = "reflaxe.allow_rose";
}
