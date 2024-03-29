// =======================================================
// * BaseTypeHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.NameMetaHelper;

/**
	Quick static extensions to help with naming.
**/
class BaseTypeHelper {
	static final IMPL_SUFFIX = "_Impl_";
	static final FIELDS_SUFFIX = "_Fields_";

	public static function namespaces(cls: BaseType): Array<String> {
		final moduleMembers = cls.module.split(".");
		final moduleName = moduleMembers[moduleMembers.length - 1];
		if(moduleName != cls.name && (moduleName + IMPL_SUFFIX) != cls.name && (moduleName + FIELDS_SUFFIX) != cls.name) {
			return moduleMembers;
		}
		return moduleMembers.slice(0, moduleMembers.length - 2);
	}

	public static function uniqueName(cls: BaseType, removeSpecialSuffixes: Bool = true): String {
		final prefix = namespaces(cls).join("_");
		var name = cls.name;
		if(removeSpecialSuffixes) {
			name = removeNameSpecialSuffixes(name);
		}
		return (prefix.length > 0 ? (prefix + "_") : "") + (cls.module == cls.name ? "" : ("_" + StringTools.replace(cls.module, ".", "_") + "_")) + name;
	}

	public static function globalName(cls: BaseType, removeSpecialSuffixes: Bool = true): String {
		final prefix = namespaces(cls).join("_");
		var name = cls.name;
		if(removeSpecialSuffixes) {
			name = removeNameSpecialSuffixes(name);
		}
		return (prefix.length > 0 ? (prefix + "_") : "") + name;
	}

	public static function removeNameSpecialSuffixes(name: String): String {
		var result = name;
		if(StringTools.endsWith(name, IMPL_SUFFIX)) {
			result = result.substring(0, result.length - IMPL_SUFFIX.length);
		}
		if(StringTools.endsWith(name, FIELDS_SUFFIX)) {
			result = result.substring(0, result.length - FIELDS_SUFFIX.length);
		}
		return result;
	}

	public static function moduleId(cls: BaseType): String {
		return StringTools.replace(cls.module, ".", "_");
	}

	public static function matchesDotPath(cls: BaseType, path: String): Bool {
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

	public static function isReflaxeExtern(cls: BaseType): Bool {
		return cls.isExtern || cls.hasMeta(":extern");
	}
}

#end
