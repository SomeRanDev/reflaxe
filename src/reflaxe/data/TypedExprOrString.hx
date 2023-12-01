package reflaxe.data;

import haxe.macro.Type;

enum ITypedExprOrString {
	Expression(expr: TypedExpr);
	String(s: String);
}

/**
	TODO: This is currently an unused type.
	Maybe delete??
**/
abstract TypedExprOrString(ITypedExprOrString) {
	inline function new(input: ITypedExprOrString) {
		this = input;
	}

	@:from public static function fromTypedExpression(expr: TypedExpr) return new TypedExprOrString(Expression(expr));
	@:from public static function fromString(s: String) return new TypedExprOrString(String(s));

	public function isExpression() return switch(this) { case Expression(_): true; case _: false; }
	public function isString() return switch(this) { case String(_): true; case _: false; }

	public function getExpression() return switch(this) { case Expression(e): e; case _: throw "Not expression"; }
	public function getString() return switch(this) { case String(s): s; case _: throw "Not string"; }
	public function getEnum(): ITypedExprOrString return this;
}
