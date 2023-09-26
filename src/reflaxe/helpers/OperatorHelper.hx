// =======================================================
// * OperatorHelper
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;

/**
	Helpful functions when using Haxe's `Binop` and `Unop` classes.
**/
class OperatorHelper {

	// Binop

	public static function binopToString(op: Binop): String {
		return switch(op) {
			case OpAdd: "+";
			case OpMult: "*";
			case OpDiv: "/";
			case OpSub: "-";
			case OpAssign: "=";
			case OpEq: "==";
			case OpNotEq: "!=";
			case OpGt: ">";
			case OpGte: ">=";
			case OpLt: "<";
			case OpLte: "<=";
			case OpAnd: "&";
			case OpOr: "|";
			case OpXor: "^";
			case OpBoolAnd: "&&";
			case OpBoolOr: "||";
			case OpShl: "<<";
			case OpShr: ">>";
			case OpUShr: ">>>";
			case OpMod: "%";
			case OpAssignOp(assignOp): binopToString(assignOp) + "=";
			case OpInterval: "...";
			case OpArrow: "=>";
			case OpIn: "in";
			case OpNullCoal: "??";
		}
	}

	public static function isEqualityCheck(op: Binop): Bool
		return switch(op) {
			case OpEq | OpNotEq: true;
			case _: false;
		}

	public static function isAssign(op: Binop): Bool
		return switch(op) {
			case OpAssign | OpAssignOp(_): true;
			case _: false;
		}

	public static function isAssignDirect(op: Binop): Bool
		return switch(op) { case OpAssign: true; case _: false; }

	public static function isAssignOp(op: Binop, innerOp: Null<Binop> = null): Bool
		return switch(op) {
			case OpAssignOp(inner) if(innerOp == null || innerOp == inner): true;
			case _: false;
		}

	public static function isAddition(op: Binop): Bool return switch(op) { case OpAdd: true; case _: false; }
	public static function isSubtraction(op: Binop): Bool return switch(op) { case OpSub: true; case _: false; }
	public static function isMultiplication(op: Binop): Bool return switch(op) { case OpMult: true; case _: false; }
	public static function isDivision(op: Binop): Bool return switch(op) { case OpDiv: true; case _: false; }

	public static function isGreaterThan(op: Binop): Bool return switch(op) { case OpGt: true; case _: false; }
	public static function isGreaterThanOrEqual(op: Binop): Bool return switch(op) { case OpGte: true; case _: false; }
	public static function isLessThan(op: Binop): Bool return switch(op) { case OpLt: true; case _: false; }
	public static function isLessThanOrEqual(op: Binop): Bool return switch(op) { case OpLte: true; case _: false; }

	public static function isEquals(op: Binop): Bool return switch(op) { case OpEq: true; case _: false; }
	public static function isNotEquals(op: Binop): Bool return switch(op) { case OpNotEq: true; case _: false; }
	public static function isBoolAnd(op: Binop): Bool return switch(op) { case OpBoolAnd: true; case _: false; }
	public static function isBoolOr(op: Binop): Bool return switch(op) { case OpBoolOr: true; case _: false; }

	public static function isBitAnd(op: Binop): Bool return switch(op) { case OpAnd: true; case _: false; }
	public static function isBitOr(op: Binop): Bool return switch(op) { case OpOr: true; case _: false; }
	public static function isBitXOr(op: Binop): Bool return switch(op) { case OpXor: true; case _: false; }

	public static function isShiftLeft(op: Binop): Bool return switch(op) { case OpShl: true; case _: false; }
	public static function isShiftRight(op: Binop): Bool return switch(op) { case OpShr: true; case _: false; }
	public static function isUnsignedShiftRight(op: Binop): Bool return switch(op) { case OpUShr: true; case _: false; }

	public static function isModulus(op: Binop): Bool return switch(op) { case OpMod: true; case _: false; }
	public static function isInterval(op: Binop): Bool return switch(op) { case OpInterval: true; case _: false; }
	public static function isArrow(op: Binop): Bool return switch(op) { case OpArrow: true; case _: false; }
	public static function isIn(op: Binop): Bool return switch(op) { case OpIn: true; case _: false; }

	// Unop

	public static function unopToString(op: Unop): String {
		return switch(op) {
			case OpIncrement: "++";
			case OpDecrement: "--";
			case OpNot: "!";
			case OpNeg: "-";
			case OpNegBits: "~";
			case OpSpread: "...";
		}
	}

	public static function isIncrement(op: Unop): Bool return switch(op) { case OpIncrement: true; case _: false; }
	public static function isDecrement(op: Unop): Bool return switch(op) { case OpDecrement: true; case _: false; }
	public static function isBoolNot(op: Unop): Bool return switch(op) { case OpNot: true; case _: false; }
	public static function isNegative(op: Unop): Bool return switch(op) { case OpNeg: true; case _: false; }
	public static function isBitNegative(op: Unop): Bool return switch(op) { case OpNegBits: true; case _: false; }
	public static function isSpread(op: Unop): Bool return switch(op) { case OpSpread: true; case _: false; }
}

#end
