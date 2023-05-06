package;

@:native("MyNativeClass")
class MyClass {
	@:native("nativeMain")
	public static function main() {
		trace("Hello world.");

		var strLen = "string object".length;
		trace(strLen);

		untyped __testscript__("{0} *** {1}", 2 + 2, "Hello");
	}

	public static function testMod(): Int {
		return 0;
	}
}
