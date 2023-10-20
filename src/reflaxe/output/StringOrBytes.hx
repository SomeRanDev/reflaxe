package reflaxe.output;

import haxe.io.Bytes;

import sys.io.File;

/**
	The underlying enum implementation for `reflaxe.output.StringOrBytes`.
**/
enum StringOrBytesImpl {
	String(s: String);
	Bytes(b: Bytes);
}

/**
	A type that can be assigned either a `String` or `haxe.io.Bytes`.

	The `save` function can be used to save the content in its
	appropriate format to a file.
**/
abstract StringOrBytes(StringOrBytesImpl) {
	inline function new(impl: StringOrBytesImpl) {
		this = impl;
	}

	public inline function data(): StringOrBytesImpl {
		return this;
	}

	@:from
	public static function fromString(s: String): StringOrBytes {
		return new StringOrBytes(StringOrBytesImpl.String(s));
	}

	@:from
	public static function fromBytes(b: Bytes): StringOrBytes {
		return new StringOrBytes(StringOrBytesImpl.Bytes(b));
	}

	public function isString(): Bool {
		return switch(this) {
			case String(_): true;
			case _: false;
		}
	}

	public function isBytes(): Bool {
		return switch(this) {
			case Bytes(_): true;
			case _: false;
		}
	}

	/**
		Saves the content using `sys.io.File.saveContent` or `sys.io.File.saveBytes`
		depending on whether storing a `String` or `haxe.io.Bytes`.
	**/
	public function save(path: String) {
		switch(this) {
			case String(s): {
				File.saveContent(path, s);
			}
			case Bytes(b): {
				File.saveBytes(path, b);
			}
		}
	}

	/**
		Checks if the stored content matches the file's content at `path`.
	**/
	public function matchesFile(path: String): Bool {
		return switch(this) {
			case String(s): {
				File.getContent(path) == s;
			}
			case Bytes(b): {
				File.getBytes(path).compare(b) == 0;
			}
		}
	}
}
