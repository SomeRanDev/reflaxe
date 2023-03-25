// =======================================================
// * ClassTypeHelper
//
// Quick static extensions to help with naming.
//
// While this class is called "ClassTypeHelper", methods
// that take "CommonModuleTypeData" are also applicable
// to EnumType, DefType, and AbstractType.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import reflaxe.helpers.ModuleTypeHelper;

import haxe.macro.Type;

class ClassTypeHelper {
	static final IMPL_SUFFIX = "_Impl_";
	static final FIELDS_SUFFIX = "_Fields_";

	public static function namespaces(cls: CommonModuleTypeData): Array<String> {
		final moduleMembers = cls.module.split(".");
		final moduleName = moduleMembers[moduleMembers.length - 1];
		if(moduleName != cls.name && (moduleName + IMPL_SUFFIX) != cls.name && (moduleName + FIELDS_SUFFIX) != cls.name) {
			return moduleMembers;
		}
		return moduleMembers.slice(0, moduleMembers.length - 2);
	}

	public static function globalName(cls: CommonModuleTypeData): String {
		final prefix = namespaces(cls).join("_");
		var name = cls.name;
		if(StringTools.endsWith(cls.name, IMPL_SUFFIX)) {
			name = name.substring(0, name.length - IMPL_SUFFIX.length);
		}
		if(StringTools.endsWith(cls.name, FIELDS_SUFFIX)) {
			name = name.substring(0, name.length - FIELDS_SUFFIX.length);
		}
		return (prefix.length > 0 ? (prefix + "_") : "") + name;
	}

	public static function moduleId(cls: CommonModuleTypeData): String {
		return StringTools.replace(cls.module, ".", "_");
	}

	public static function isTypeParameter(cls: ClassType): Bool {
		return switch(cls.kind) {
			case KTypeParameter(_): true;
			case _: false;
		}
	}

	public static function matchesDotPath(cls: CommonModuleTypeData, path: String): Bool {
		if(cls.pack.length == 0) {
			return cls.name == path;
		}
		if((cls.pack.join(".") + "." + cls.name) == path) {
			return true;
		}
		if((cls.module + "." + cls.name) == path) {
			return true;
		}
		return false;
	}
}

#end
