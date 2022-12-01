// =======================================================
// * ClassTypeHelper
//
// Quick static extensions to help with naming.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

class ClassTypeHelper {
	static final IMPL_PREFIX = "_Impl_";

	public static function namespaces(cls: ClassType): Array<String> {
		final moduleMembers = cls.module.split(".");
		final moduleName = moduleMembers[moduleMembers.length - 1];
		if(moduleName != cls.name && (moduleName + IMPL_PREFIX) != cls.name) {
			return moduleMembers;
		}
		return moduleMembers.slice(0, moduleMembers.length - 2);
	}

	public static function globalName(cls: ClassType): String {
		final prefix = namespaces(cls).join("_");
		final name = StringTools.endsWith(cls.name, IMPL_PREFIX) ? cls.name.substring(0, cls.name.length - IMPL_PREFIX.length) : cls.name;
		return (prefix.length > 0 ? (prefix + "_") : "") + name;
	}

	public static function moduleId(cls: ClassType): String {
		return StringTools.replace(cls.module, ".", "_");
	}
}

#end
