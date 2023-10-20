package reflaxe.output;

import haxe.macro.Type;

/**
	Stores an arbitrary piece of data with associated file metadata.
**/
typedef DataAndFileInfo<T> = {
	data: T,
	baseType: BaseType,
	fileName: Null<String>,
	directory: Null<String>
};
