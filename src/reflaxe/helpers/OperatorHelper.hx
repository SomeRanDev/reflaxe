// =======================================================
// * OperatorHelper
//
// Helpful functions when using Haxe's Binop and Unop classes.
// =======================================================

package reflaxe.helpers;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;

class OperatorHelper {
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
			#if (haxe_ver >= "4.3.0")
			case OpNullCoal: "??";
			#end
		}
	}

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

	public static function isAddition(op: Binop): Bool {
		return switch(op) {
			case OpAdd: true;
			case _: false;
		}
	}

	public static function isEqualityCheck(op: Binop): Bool {
		return switch(op) {
			case OpEq | OpNotEq: true;
			case _: false;
		}
	}

	public static function isEquals(op: Binop): Bool {
		return switch(op) {
			case OpEq: true;
			case _: false;
		}
	}

	public static function isNotEquals(op: Binop): Bool {
		return switch(op) {
			case OpNotEq: true;
			case _: false;
		}
	}
}

#end
