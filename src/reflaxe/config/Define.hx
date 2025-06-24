package reflaxe.config;

enum abstract Define(String) from String to String {
	/**
		-D reflaxe.allow_rose

		Enables the "reassign on subfield edit" feature.
		This allows the `@:reassignOnSubfieldEdit` meta to be used.

		See `reflaxe/compiler/ReassignOnSubfieldEdit.hx`.
	**/
	var AllowROSE = "reflaxe.allow_rose";

	/**
		-D reflaxe.only_generate=["pack1", "pack2.something", ...]

		Has Reflaxe only generate module types contained within the
		provided array of strings.
	**/
	var OnlyGenerate = "reflaxe.only_generate";

	/**
		-D reflaxe.generate_everything_except=["pack1", "pack2.something", ...]

		Has Reflaxe generate all module types except the ones contained
		within the provided array of strings.
	**/
	var GenerateEverythingExcept = "reflaxe.generate_everything_except";

	/**
		-D reflaxe.disallow_build_cache_check

		If defined, the module-cache check using build macros that is
		employed upon subsequent `--connect` runs will not occur.

		This may be necessary for Reflaxe targets that modify global state in a
		way that requires all types to be recompiled for proper generation.
	**/
	var DisallowBuildCacheCheck = "reflaxe.disallow_build_cache_check";

	/**
		-D reflaxe.dont_output_metadata_id

		If defined, the `id` entry in the output metadata will always be `0`.
		This is useful for testing Reflaxe targets and ensuring the output is always identical.
	**/
	var DontOutputMetadataId = "reflaxe.dont_output_metadata_id";
}
