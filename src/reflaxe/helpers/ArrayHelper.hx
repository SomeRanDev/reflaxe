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
		Checks if the two arrays are equal using the equality
		operator on each value.
	**/
	public static function equals<T>(self: Array<T>, other: Array<T>) {
		if(self.length != other.length) {
			return false;
		}
		for(i in 0...self.length) {
			if(self[i] != other[i]) {
				return false;
			}
		}
		return true;
	}

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

	/**
		If `other` is not `null`, works just like `concat`.
		If it IS `null`, this just returns `self`.
	**/
	public static function concatIfNotNull<T>(self: Array<T>, other: Null<Array<T>>) {
		if(other == null) {
			return self;
		}
		return self.concat(other);
	}
}

#end
