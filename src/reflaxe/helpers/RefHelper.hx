package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Type.Ref;

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