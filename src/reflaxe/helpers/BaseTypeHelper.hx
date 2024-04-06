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

	public static function namespaces(self: BaseType): Array<String> {
		final moduleMembers = self.module.split(".");
		final moduleName = moduleMembers[moduleMembers.length - 1];
		if(moduleName != self.name && (moduleName + IMPL_SUFFIX) != self.name && (moduleName + FIELDS_SUFFIX) != self.name) {
			return moduleMembers;
		}
		return moduleMembers.slice(0, moduleMembers.length - 2);
	}

	public static function uniqueName(self: BaseType, removeSpecialSuffixes: Bool = true): String {
		final prefix = namespaces(self).join("_");
		var name = self.name;
		if(removeSpecialSuffixes) {
			name = removeNameSpecialSuffixes(name);
		}
		return (prefix.length > 0 ? (prefix + "_") : "") + (self.module == self.name ? "" : ("_" + StringTools.replace(self.module, ".", "_") + "_")) + name;
	}

	public static function globalName(self: BaseType, removeSpecialSuffixes: Bool = true): String {
		final prefix = namespaces(self).join("_");
		var name = self.name;
		if(removeSpecialSuffixes) {
			name = removeNameSpecialSuffixes(name);
		}
		return (prefix.length > 0 ? (prefix + "_") : "") + name;
	}

	public static function equals(self: BaseType, other: BaseType): Bool {
		return uniqueName(self) == uniqueName(other);
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

	public static function moduleId(self: BaseType): String {
		return StringTools.replace(self.module, ".", "_");
	}

	public static function matchesDotPath(self: BaseType, path: String): Bool {
		if(self.pack.length == 0) {
			return self.name == path;
		}
		if((self.pack.join(".") + "." + self.name) == path) {
			return true;
		}
		if((self.module + "." + self.name) == path) {
			return true;
		}
		return false;
	}

	public static function isReflaxeExtern(self: BaseType): Bool {
		return self.isExtern || self.hasMeta(":extern");
	}
}

#end
