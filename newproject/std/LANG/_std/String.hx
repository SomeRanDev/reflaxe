package;

/**
	Your target needs to provide custom implementations of every Haxe API class.
	How this is achieved is different for each target, so be sure to research and try different methods!

	To help you get started, this String.hx was provided.
	But you'll need to handle the rest from here!

	This file is based on the cross implementation for String:
	https://github.com/HaxeFoundation/haxe/blob/development/std/String.hx

	-- Examples --
	JavaScript  https://github.com/HaxeFoundation/haxe/tree/development/std/js/_std/String.hx
	Hashlink    https://github.com/HaxeFoundation/haxe/blob/development/std/hl/_std/String.hx
	Python      https://github.com/HaxeFoundation/haxe/blob/development/std/python/_std/String.hx
**/
extern class String {
	var length(default, null):Int;

	function new(string:String):Void;

	function toUpperCase():String;
	function toLowerCase():String;
	function charAt(index:Int):String;
	function charCodeAt(index:Int):Null<Int>;
	function indexOf(str:String, ?startIndex:Int):Int;
	function lastIndexOf(str:String, ?startIndex:Int):Int;
	function split(delimiter:String):Array<String>;
	function substr(pos:Int, ?len:Int):String;
	function substring(startIndex:Int, ?endIndex:Int):String;
	function toString():String;

	@:pure static function fromCharCode(code:Int):String;
}
