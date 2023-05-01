package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFuncData {
	public var classType(default, null): ClassType;
	public var field(default, null): ClassField;

	public var isStatic(default, null): Bool;
	public var kind(default, null): MethodKind;

	public var ret(default, null): Type;
	public var args(default, null): Array<ClassFuncArg>;
	public var tfunc(default, null): Null<TFunc>;
	public var expr(default, null): Null<TypedExpr>;

	public function new(classType: ClassType, field: ClassField, isStatic: Bool, kind: MethodKind, ret: Type, args: Array<ClassFuncArg>, tfunc: Null<TFunc>, expr: Null<TypedExpr>) {
		this.classType = classType;
		this.field = field;

		this.isStatic = isStatic;
		this.kind = kind;

		this.ret = ret;
		this.args = args;
		this.tfunc = tfunc;
		this.expr = expr;
	}

	public function setExpr(e: TypedExpr) {
		expr = e;
	}

	/**
		Checks if the `args` of both `ClassFuncData` are identical.
	**/
	public function argumentsMatch(childData: ClassFuncData) {
		if(args.length != childData.args.length) {
			return false;
		}

		// Covariance does not apply with arguments.
		// They must be identical to override (right?)
		// TODO: Typedefs/abstracts should count?
		for(i in 0...args.length) {
			if(!args[i].type.equals(childData.args[i].type)) {
				return false;
			}
		}
		return true;
	}

	/**
		Given a list of expressions to be passed as arguments to
		this function, this returns a modified list that replaces
		all instances of `null` on an argument with a default
		value with that default value.
	**/
	public function replacePadNullsWithDefaults(passedArgs: Array<TypedExpr>): Array<TypedExpr> {
		var hasDefaults = false;
		for(a in args) {
			if(a.expr != null) {
				hasDefaults = true;
				break;
			}
		}
		if(!hasDefaults) {
			return passedArgs;
		}

		final result: Array<TypedExpr> = [];
		for(i in 0...args.length) {
			final arg = args[i];
			final hasPassedArg = i < passedArgs.length;
			final useDefault = !hasPassedArg || passedArgs[i].isNullExpr();
			if(useDefault && arg.expr != null && !arg.hasConflicingDefaultValue()) {
				result.push(arg.expr);
			} else if(hasPassedArg) {
				result.push(passedArgs[i]);
			}
		}
		return result;
	}

	/**
		If this function has optional arguments, this function will
		return a list of all possible argument combinations that can
		be passed.
	**/
	public function findAllArgumentVariations(frontOptionalsOnly: Bool = false, preventRepeats: Bool = false): Array<{ args: Array<ClassFuncArg>, padExprs: Array<TypedExpr> }> {
		var hasRequired = false;
		final optionalIndexes = [];
		for(i in 0...args.length) {
			if(args[i].opt) {
				optionalIndexes.push(i);
			} else {
				hasRequired = true;
				if(frontOptionalsOnly) {
					break;
				}
			}
		}

		// If there are no optional arguments, there is only one possibility.
		if(optionalIndexes.length == 0) {
			return [{ args: args, padExprs: args.map(a -> TypedExprHelper.make(TIdent(a.name), a.type)) }];
		}

		// If every argument is optional and `frontOptionalsOnly`, there are no variations.
		if(!hasRequired && frontOptionalsOnly) {
			return [];
		}

		final result = [];
		final optionalCount = optionalIndexes.length;
		final possibleCombos = Std.int(Math.pow(2, optionalCount));
		for(comboID in 0...possibleCombos) {
			final tempArgs = [];
			final padExprs = [];

			for(j in 0...args.length) {
				final index = optionalIndexes.indexOf(j);
				final arg = args[j];

				// If the argument isn't optional, OR the bit index is 1 in `comboID`,
				// add it to this list of arguments.
				if(index < 0 || ((comboID & Std.int(Math.pow(2, index))) > 0)) {
					tempArgs.push(arg);
					padExprs.push(TypedExprHelper.make(TIdent(arg.name), arg.type));
				} else {
					padExprs.push(arg.expr ?? TypedExprHelper.make(TConst(TNull), arg.type));
				}
			}

			result.push({ args: tempArgs, padExprs: padExprs });
		}

		if(preventRepeats) {
			final keys: Map<String, Bool> = [];
			final newResult = [];
			for(data in result) {
				final key = Std.string(data.args.map(a -> a.type));
				if(!keys.exists(key)) {
					keys.set(key, true);
					newResult.push(data);
				}
			}
			return newResult;
		}

		return result;
	}
}

#end
