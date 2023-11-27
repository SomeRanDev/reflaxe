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
class ArrayHelper {
	/**
		Works the same as `Array.join`, but if the array is not empty,
		the `connector` is appended to the resulting `String`.

		If the array IS empty, an empty string is returned.

		Useful for generating full class paths:
		```haxe
		cls.pack.joinAppend(".") + cls.name;
		```
	**/
	public static function joinAppend<T>(arr: Array<T>, connector: String) {
		return if(arr.length == 0) "";
		else arr.join(connector) + connector;
	}
}

#end
