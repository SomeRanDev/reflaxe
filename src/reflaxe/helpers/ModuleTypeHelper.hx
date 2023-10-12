// =======================================================
// * ModuleTypeHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.NameMetaHelper;

/**
	Class for extracting common data shared between the
	`ModuleType` declaration classes.
**/
class ModuleTypeHelper {
	public static function getCommonData(type: ModuleType): BaseType {
		return switch(type) {
			case TClassDecl(c): c.get();
			case TEnumDecl(e): e.get();
			case TTypeDecl(t): t.get();
			case TAbstract(a): a.get();
		}
	}

	public static function getPos(type: ModuleType): Position {
		return getCommonData(type).pos;
	}

	public static function getModule(type: ModuleType): String {
		return getCommonData(type).module;
	}

	public static function getPath(type: ModuleType): String {
		final data = getCommonData(type);
		return if(StringTools.endsWith(data.module, data.name)) {
			data.module;
		} else {
			data.module + "." + data.name;
		}
	}

	public static function getNameOrNative(type: ModuleType): String {
		return getCommonData(type).getNameOrNative();
	}

	public static function getUniqueId(type: ModuleType): String {
		final prefix = switch(type) {
			case TClassDecl(_): "C";
			case TEnumDecl(_): "E";
			case TTypeDecl(_): "T";
			case TAbstract(_): "A";
		}

		final d = getCommonData(type);
		return prefix + "|" + d.pack.join("_") + d.globalName(false);
	}

	public static function equals(type: Null<ModuleType>, other: Null<ModuleType>): Bool {
		if(type == null || other == null) return false;
		return getUniqueId(type) == getUniqueId(other);
	}

	public static function isClass(type: ModuleType): Bool {
		return switch(type) {
			case TClassDecl(_): true;
			case _: false;
		}
	}

	public static function isEnum(type: ModuleType): Bool {
		return switch(type) {
			case TEnumDecl(_): true;
			case _: false;
		}
	}

	public static function isTypedef(type: ModuleType): Bool {
		return switch(type) {
			case TTypeDecl(_): true;
			case _: false;
		}
	}

	public static function isAbstract(type: ModuleType): Bool {
		return switch(type) {
			case TAbstract(_): true;
			case _: false;
		}
	}
}

#end
