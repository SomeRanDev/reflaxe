package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.TVar;

typedef RTypedExpr = #if (neko || eval || display) haxe.macro.Type.TypedExpr #else Dynamic #end;

/**
	`haxe.macro.Context` loses fields outside of a macro context.
	This causes issues with IDE usage since code needs to be "runtime-compatible",
	to be used with Visual Studio Code and null-safety checked.

	This class is a replacement for `Context`, providing all the same
	functions, but they can exist at runtime.
**/
class RContext {
	public static function error(msg:String, pos:Position): Dynamic {
		#if (neko || eval || display)
		return Context.error(msg, pos);
		#else
		return null;
		#end
	}

	public static function fatalError(msg:String, pos:Position):Dynamic {
		#if (neko || eval || display)
		return Context.fatalError(msg, pos);
		#else
		return null;
		#end
	}

	public static function warning(msg:String, pos:Position) {
		#if (neko || eval || display)
		return Context.warning(msg, pos);
		#else
		return null;
		#end
	}

	public static function info(msg:String, pos:Position) {
		#if (neko || eval || display)
		return Context.info(msg, pos);
		#else
		return null;
		#end
	}

	public static function getMessages() : Array<Message> {
		#if (neko || eval || display)
		return Context.getMessages();
		#else
		return [];
		#end
	}

	public static function filterMessages( predicate : Message -> Bool ) {
		#if (neko || eval || display)
		Context.filterMessages(predicate);
		#end
	}

	public static function resolvePath(file:String):String {
		#if (neko || eval || display)
		return Context.resolvePath(file);
		#else
		return "";
		#end
	}

	public static function getClassPath():Array<String> {
		#if (neko || eval || display)
		return Context.getClassPath();
		#else
		return [];
		#end
	}

	public static function containsDisplayPosition(pos:Position):Bool {
		#if (neko || eval || display)
		return Context.containsDisplayPosition(pos);
		#else
		return false;
		#end
	}

	public static function currentPos():Position {
		#if (neko || eval || display)
		return Context.currentPos();
		#else
		return {min:0,max:0,file:""};
		#end
	}

	public static function getExpectedType():Null<haxe.macro.Type> {
		#if (neko || eval || display)
		return Context.getExpectedType();
		#else
		return null;
		#end
	}

	public static function getCallArguments():Null<Array<Expr>> {
		#if (neko || eval || display)
		return Context.getCallArguments();
		#else
		return null;
		#end
	}

	public static function getLocalClass() {
		#if (neko || eval || display)
		return Context.getLocalClass();
		#else
		return null;
		#end
	}

	public static function getLocalModule():String {
		#if (neko || eval || display)
		return Context.getLocalModule();
		#else
		return "";
		#end
	}

	public static function getLocalType():Null<haxe.macro.Type> {
		#if (neko || eval || display)
		return Context.getLocalType();
		#else
		return null;
		#end
	}

	public static function getLocalMethod():Null<String> {
		#if (neko || eval || display)
		return Context.getLocalMethod();
		#else
		return null;
		#end
	}

	public static function getLocalUsing() {
		#if (neko || eval || display)
		return Context.getLocalUsing();
		#else
		return [];
		#end
	}

	public static function getLocalImports():Array<ImportExpr> {
		#if (neko || eval || display)
		return Context.getLocalImports();
		#else
		return [];
		#end
	}

	public static function getLocalTVars():Map<String, #if (neko || eval || display) haxe.macro.Type.TVar #else Dynamic #end> {
		#if (neko || eval || display)
		return Context.getLocalTVars();
		#else
		return [];
		#end
	}

	public static function defined(s:String):Bool {
		#if (neko || eval || display)
		return Context.defined(s);
		#else
		return false;
		#end
	}

	public static function definedValue(key:String):String {
		#if (neko || eval || display)
		return Context.definedValue(key);
		#else
		return "";
		#end
	}

	public static function getDefines():Map<String, String> {
		#if (neko || eval || display)
		return Context.getDefines();
		#else
		return [];
		#end
	}

	public static function getType(name:String):haxe.macro.Type {
		#if (neko || eval || display)
		return Context.getType(name);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function getModule(name:String):Array<haxe.macro.Type> {
		#if (neko || eval || display)
		return Context.getModule(name);
		#else
		return [];
		#end
	}

	public static function parse(expr:String, pos:Position):Expr {
		#if (neko || eval || display)
		return Context.parse(expr, pos);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function parseInlineString(expr:String, pos:Position):Expr {
		#if (neko || eval || display)
		return Context.parseInlineString(expr, pos);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function makeExpr(v:Dynamic, pos:Position):Expr {
		#if (neko || eval || display)
		return Context.makeExpr(v, pos);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function signature(v:Dynamic):String {
		#if (neko || eval || display)
		return Context.signature(v);
		#else
		return "";
		#end
	}

	public static function onGenerate(callback:Array<haxe.macro.Type>->Void, persistent:Bool = true) {
		#if (neko || eval || display)
		return Context.onGenerate(callback, persistent);
		#end
	}

	public static function onAfterGenerate(callback:Void->Void) {
		#if (neko || eval || display)
		return Context.onAfterGenerate(callback);
		#end
	}

	public static function onAfterTyping(callback:Array<haxe.macro.Type.ModuleType>->Void) {
		#if (neko || eval || display)
		return Context.onAfterTyping(callback);
		#end
	}

	public static function onTypeNotFound(callback:String->TypeDefinition) {
		#if (neko || eval || display)
		return Context.onTypeNotFound(callback);
		#end
	}

	public static function typeof(e:Expr):haxe.macro.Type {
		#if (neko || eval || display)
		return Context.typeof(e);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function typeExpr(e:Expr):RTypedExpr {
		#if (neko || eval || display)
		return Context.typeExpr(e);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function resolveType(t:ComplexType, p:Position):haxe.macro.Type {
		#if (neko || eval || display)
		return Context.resolveType(t, p);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function toComplexType(t:haxe.macro.Type):Null<ComplexType> {
		#if (neko || eval || display)
		return Context.toComplexType(t);
		#else
		return null;
		#end
	}

	public static function unify(t1:haxe.macro.Type, t2:haxe.macro.Type):Bool {
		#if (neko || eval || display)
		return Context.unify(t1, t2);
		#else
		return false;
		#end
	}

	public static function follow(t:haxe.macro.Type, ?once:Bool):haxe.macro.Type {
		#if (neko || eval || display)
		return Context.follow(t, once);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function followWithAbstracts(t:haxe.macro.Type, once:Bool = false):haxe.macro.Type {
		#if (neko || eval || display)
		return Context.followWithAbstracts(t, once);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function getPosInfos(p:Position):{min:Int, max:Int, file:String} {
		#if (neko || eval || display)
		return Context.getPosInfos(p);
		#else
		return {min:0,max:0,file:""};
		#end
	}

	public static function makePosition(inf:{min:Int, max:Int, file:String}):Position {
		#if (neko || eval || display)
		return Context.makePosition(inf);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function getResources():Map<String, haxe.io.Bytes> {
		#if (neko || eval || display)
		return Context.getResources();
		#else
		return [];
		#end
	}

	public static function addResource(name:String, data:haxe.io.Bytes) {
		#if (neko || eval || display)
		Context.addResource(name, data);
		#end
	}

	public static function getBuildFields():Array<Field> {
		#if (neko || eval || display)
		return Context.getBuildFields();
		#else
		return [];
		#end
	}

	public static function defineType(t:TypeDefinition, ?moduleDependency:String):Void {
		#if (neko || eval || display)
		Context.defineType(t, moduleDependency);
		#end
	}

	public static function defineModule(modulePath:String, types:Array<TypeDefinition>, ?imports:Array<ImportExpr>, ?usings:Array<TypePath>):Void {
		#if (neko || eval || display)
		Context.defineModule(modulePath, types, imports, usings);
		#end
	}

	public static function getTypedExpr(t:RTypedExpr):Expr {
		#if (neko || eval || display)
		return Context.getTypedExpr(t);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function storeTypedExpr(t:RTypedExpr):Expr {
		#if (neko || eval || display)
		return Context.storeTypedExpr(t);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function storeExpr(e:Expr):Expr {
		#if (neko || eval || display)
		return Context.storeExpr(e);
		#else
		throw "Cannot call at runtime";
		#end
	}

	public static function registerModuleDependency(modulePath:String, externFile:String) {
		#if (neko || eval || display)
		Context.registerModuleDependency(modulePath, externFile);
		#end
	}

	public static function timer(id:String):()->Void {
		#if (neko || eval || display)
		return Context.timer(id);
		#else
		throw "Cannot call at runtime";
		#end
	}
}

#end
