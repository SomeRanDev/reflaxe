package reflaxe.output;

import haxe.macro.Type;

/**
	Stores an arbitrary piece of data with associated file metadata.
**/
class DataAndFileInfo<T> {
	public var data(default, null): T;
	public var baseType(default, null): BaseType;
	public var overrideFileName(default, null): Null<String>;
	public var overrideDirectory(default, null): Null<String>;

	public function new(data: T, baseType: BaseType, overrideFileName: Null<String>, overrideDirectory: Null<String>) {
		this.data = data;
		this.baseType = baseType;
		this.overrideFileName = overrideFileName;
		this.overrideDirectory = overrideDirectory;
	}

	/**
		Generates a copy with a different `data` but the same file metadata. 
	**/
	public function with<T>(newData: T) {
		return new DataAndFileInfo(newData, baseType, overrideFileName, overrideDirectory);
	}

	/**
		Generates a copy with `StringOrBytes`.

		This function exists since auto-conversion from `String` or `Bytes` doesn't
		work with the generic `with` version.
	**/
	public function withOutput(output: StringOrBytes) {
		return new DataAndFileInfo(output, baseType, overrideFileName, overrideDirectory);
	}
}
