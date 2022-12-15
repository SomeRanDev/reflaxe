// =======================================================
// * OutputPath
//
// A class created from either a String or an Array to
// represent a file path.
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

abstract OutputPath(Array<String>) from Array<String> {
	public function new(arr: Array<String>) {
		this = arr;
	}

	@:from
	public static function fromArr(arr: Array<String>): OutputPath {
		return new OutputPath(arr);
	}

	@:from
	public static function fromStr(str: String): OutputPath {
		return new OutputPath(~/(\/|\\)+/.split(str));
	}

	public function toString(): String {
		return this.join("/");
	}
}

#end
