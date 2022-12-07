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
	static final IMPL_PREFIX = "_Impl_";

	public static function namespaces(cls: CommonModuleTypeData): Array<String> {
		final moduleMembers = cls.module.split(".");
		final moduleName = moduleMembers[moduleMembers.length - 1];
		if(moduleName != cls.name && (moduleName + IMPL_PREFIX) != cls.name) {
			return moduleMembers;
		}
		return moduleMembers.slice(0, moduleMembers.length - 2);
	}

	public static function globalName(cls: CommonModuleTypeData): String {
		final prefix = namespaces(cls).join("_");
		final name = StringTools.endsWith(cls.name, IMPL_PREFIX) ? cls.name.substring(0, cls.name.length - IMPL_PREFIX.length) : cls.name;
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
}

#end
