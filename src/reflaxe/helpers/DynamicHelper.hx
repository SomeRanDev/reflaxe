// =======================================================
// * DynamicHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

/**
	Quick static extensions to help with `Dynamic`.
**/
class DynamicHelper {
	public static function isString(d: Dynamic): Bool {
		return Std.string(Type.typeof(d)) == "TClass(Class<String>)";
	}

	/**
		Modifies the properties of a Dynamic object.
	**/
	public static function with(d: Dynamic, props: Dynamic): Dynamic {
		final result = Reflect.copy(d);
		for(prop in Reflect.fields(props)) {
			Reflect.setField(result, prop, Reflect.field(props, prop));
		}
		return result;
	}
}

#end
