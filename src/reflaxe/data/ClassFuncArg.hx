package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.input.ClassHierarchyTracker;

using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFuncArg {
	public var funcData(default, null): Null<ClassFuncData>;
	public var index(default, null): Int;

	public var type(default, null): Type;
	public var opt(default, null): Bool;
	public var name(default, null): String;
	public var expr(default, null): Null<TypedExpr>;
	public var tvar(default, null): Null<TVar>;

	public function new(index: Int, type: Type, opt: Bool, name: String, expr: Null<TypedExpr> = null, tvar: Null<TVar> = null) {
		this.index = index;

		this.type = type;
		this.opt = opt;
		this.name = name;
		this.expr = expr;
		this.tvar = tvar;
	}

	/**
		Assigning the `ClassFuncData` is delayed so the arguments
		can be passed first.
	**/
	public function setFuncData(funcData: ClassFuncData) {
		this.funcData = funcData;
	}

	/**
		Returns true if this argument is optional but doesn't
		have a default value.
	**/
	public function isOptionalWithNoDefault() {
		return opt && expr == null;
	}

	/**
		Returns true if this argument is optional, but there
		are subsequent arguments that are not.
	**/
	public function isFrontOptional() {
		final args = funcData.trustMe().args;
		for(i in index...args.length) {
			if(!args[i].opt) {
				return true;
			}
		}
		return false;
	}

	/**
		If this argument's function is overriden or is overriding a
		function with a different default value for this argument,
		this returns true.
	**/
	public function hasConflicingDefaultValue(): Bool {
		if(funcData.trustMe().isStatic) {
			return false;
		}

		final overrides = ClassHierarchyTracker.findAllOverrides(funcData.trustMe());
		for(funcData in overrides) {
			if(funcData != null && funcData.args.length > index) {
				final otherDefault = funcData.args[index].expr;

				// check if both have default values
				if(expr != null && otherDefault != null) {
					if(!expr.equals(otherDefault)) {
						return true;
					}
				}

				// check if one has default value but other doesn't
				else if(expr != null || otherDefault != null) {
					return true;
				}
			}
		}
		return false;
	}

	/**
		Convert this class to a String representation.
	**/
	public function toString(): String {
		return (opt ? "?" : "") + name + ": " + type + (expr != null ? Std.string(expr) : "");
	}
}

#end
