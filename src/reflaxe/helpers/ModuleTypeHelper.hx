// =======================================================
// * CommonModuleTypeData
//
// Class for extracting common data shared between the
// ModuleType declaration classes.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ClassTypeHelper;
using reflaxe.helpers.NameMetaHelper;

typedef CommonModuleTypeData = {
	pack: Array<String>,
	pos: Position,
	meta: MetaAccess,
	module: String,
	name: String
}

class ModuleTypeHelper {
	public static function getCommonData(type: ModuleType): CommonModuleTypeData {
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

		return prefix + "|" + getCommonData(type).globalName();
	}
}

#end
