package reflaxe.helpers;

import haxe.macro.Type.Ref;
#if (macro || reflaxe_runtime)

class RefHelper {
	public static function buildRef<T>(c:T):Ref<T> {
		return {
			get: () -> c,
			toString: () -> Std.string(c)
		}
	}

	public static function replaceRef<T>(ref:Ref<T>, newValue:T):Ref<T> {
		Reflect.setField(ref, "get", () -> newValue);
		return ref;
	}
}

#end