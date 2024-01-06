package reflaxe.data;

#if (macro || reflaxe_runtime)

import reflaxe.helpers.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.PositionHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFuncData {
	public var classType(default, null): ClassType;
	public var field(default, null): ClassField;

	public var isStatic(default, null): Bool;
	public var kind(default, null): MethodKind;

	public var ret(default, null): Type;
	public var args(default, null): Array<ClassFuncArg>;
	public var argsMeta(default, null): Null<Array<Metadata>>;
	public var tfunc(default, null): Null<TFunc>;
	public var expr(default, null): Null<TypedExpr>;

	public var property(default, null): Null<ClassField>;

	var variableUsageCount: Null<Map<Int, Int>>; // Access using `getOrFindVariableUsageCount`

	public function new(classType: ClassType, field: ClassField, isStatic: Bool, kind: MethodKind, ret: Type, args: Array<ClassFuncArg>, tfunc: Null<TFunc>, expr: Null<TypedExpr>) {
		this.classType = classType;
		this.field = field;

		this.isStatic = isStatic;
		this.kind = kind;

		this.ret = ret;
		this.args = args;
		this.tfunc = tfunc;
		this.expr = expr;

		extractArgumentMeta();
		findProperty();
	}

	/**
		TODO: Anyway I could make this... more condensed?
	**/
	function findProperty() {
		if(isGetterName()) {
			final propName = field.getHaxeName().substr("get_".length);
			if(propName.length == 0) return;
			for(f in (isStatic ? classType.statics : classType.fields).get()) {
				final hasGetter = switch(f.kind) {
					case FVar(AccCall, _): true;
					case _: false;
				}
				if(hasGetter && f.getHaxeName() == propName) {
					property = f;
					break;
				}
			}
		} else if(isSetterName()) {
			final propName = field.getHaxeName().substr("set_".length);
			if(propName.length == 0) return;
			for(f in (isStatic ? classType.statics : classType.fields).get()) {
				final hasSetter = switch(f.kind) {
					case FVar(_, AccCall): true;
					case _: false;
				}
				if(hasSetter && f.getHaxeName() == propName) {
					property = f;
					break;
				}
			}
		}
	}

	/**
		At the current moment, argument metadata is not retained.

		To read argument metadata, the `@:argMeta(index: Int, callExpr: Expr)`
		meta can be applied to the field to setup "metadata" for the
		arguments.
	**/
	function extractArgumentMeta() {
		for(meta in field.meta.get()) {
			if(meta.name == ":argMeta") {
				switch(meta.params) {
					case [
						{ expr: EConst(CInt(Std.parseInt(_) => index)) },
						{ expr: ECall({ expr: EConst(constant) }, metaArgs) }
					] if(index != null): {
						if(index < args.length) {
							final metaName = switch(constant) {
								case CIdent(s): s;
								case CString(s, _): s;
								case _: continue;
							}
							args[index].addExtraMetadata({
								name: metaName,
								pos: meta.pos,
								params: metaArgs
							});
						}
					}
					case _:
				}
			}
		}
	}

	inline function isGetterName() return StringTools.startsWith(field.getHaxeName(), "get_");
	inline function isSetterName() return StringTools.startsWith(field.getHaxeName(), "set_");

	public function isGetter() {
		return isGetterName() && property != null;
	}

	public function isSetter() {
		return isSetterName() && property != null;
	}

	public function setExpr(e: TypedExpr) {
		expr = e;
	}

	/**
		Returns the variable usage count.
		If it has not been calculated yet, it is calculated here.
	**/
	public function getOrFindVariableUsageCount(): Map<Int, Int> {
		if(expr == null) {
			return [];
		}

		final map: Map<Int, Int> = [];
		function count(e: TypedExpr) {
			switch(e.expr) {
				case TVar(tvar, _): {
					map.set(tvar.id, 0);
				}
				case TLocal(tvar): {
					map.set(tvar.id, (map.get(tvar.id) ?? 0) + 1);
				}
				case _:
			}
			return haxe.macro.TypedExprTools.map(e, count);
		}
		count(expr);
		return variableUsageCount = map;
	}

	/**
		A map of the number of times a variable is used can optionally
		be provided for later reference.

		This is usually calculated using `EverythingIsExprSanitizer` prior
		to other optimizations. 
	**/
	public function setVariableUsageCount(usageMap: Map<Int, Int>) {
		variableUsageCount = usageMap;
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

		If "noNullPadMeta" is defined, this will be treated
		as the name of a meta on an argument that can be used to
		specify native code (using a single `String` argument) to
		use instead of `null`.

		For example, if `noNullPadMeta = ":noNullPad"`, then
		the metadata it's looking for is:
		```haxe
		function myFunc(@:noNullPad("targetLanguageCode") ?myArg: Int);
		```

		"nativeExpressionGenerator" MUST also be defined if "noNullPadMeta"
		is. This will be given the argument and position of the meta and should
		transform it into the target's desired `TypedExpr` format.

		If the "noNullPadMeta" metadata does not have an argument, its `null`
		padding will be removed if possible. If this is not possible a compile-
		time error will occur.
	**/
	public function replacePadNullsWithDefaults(
		passedArgs: Array<TypedExpr>,
		noNullPadMeta: Null<String> = null,
		nativeExpressionGenerator: Null<(String, Position) -> TypedExpr> = null
	): Array<TypedExpr> {
		if(noNullPadMeta != null && nativeExpressionGenerator == null) {
			throw "Missing \"nativeExpressionGenerator\" argument.";
		}

		var hasDefaults = false;
		for(a in args) {
			if(a.expr != null || (noNullPadMeta != null && a.hasMetadata(noNullPadMeta))) {
				hasDefaults = true;
				break;
			}
		}
		if(!hasDefaults) {
			return passedArgs;
		}

		var nullPadRemovedAtIndex = null;

		final result: Array<TypedExpr> = [];
		for(i in 0...args.length) {
			final arg = args[i];
			final hasPassedArg = i < passedArgs.length;
			final useDefault = !hasPassedArg || passedArgs[i].isNullExpr();
			
			final noNullPad = noNullPadMeta != null ? arg.hasMetadata(noNullPadMeta) : false;
			final noNullPadDefaultValue = noNullPad ? arg.getMetadataFirstString(noNullPadMeta.trustMe()) : null;

			var resultValue = null;

			if(useDefault && (arg.expr != null || noNullPad)) {
				if(noNullPad) {
					if(noNullPadDefaultValue == null) {
						nullPadRemovedAtIndex = i;
					} else if(nativeExpressionGenerator != null) {
						final pos = arg.getMetadataFirstPosition(noNullPadMeta.trustMe()).trustMe();
						resultValue = nativeExpressionGenerator(noNullPadDefaultValue, pos);
					}
				} else if(arg.hasConflictingDefaultValue()) {
					// If there's a conflicting default value, pass `null` anyway.
					// But we'll mark this `null` with a meta to help track it.
					final e: Null<TypedExpr> = passedArgs[i];
					if(e != null) {
						resultValue = {
							expr: TMeta({ name: "-conflicting-default-value", pos: e.pos }, e),
							pos: e.pos,
							t: e.t
						};
					}
				} else if(arg.expr != null) {
					resultValue = arg.expr;
				}
			} else if(hasPassedArg) {
				resultValue = passedArgs[i];
			}

			if(resultValue != null) {
				if(nullPadRemovedAtIndex != null) {
					Context.error('`null` padding removed at index $nullPadRemovedAtIndex, but argument still exists at index $i.', {
						if(hasPassedArg) passedArgs[i].pos;
						else if(passedArgs.length > 0) passedArgs[passedArgs.length - 1].pos;
						else Context.currentPos();
					});
				}
				result.push(resultValue);
			}
		}
		return result;
	}

	/**
		If this function has optional arguments, this function will
		return a list of all possible argument combinations that can
		be passed.

		Enabling `frontOptionalsOnly` will make it so only variations
		for optional arguments that have required arguments after
		them will be generated. If every argument is optional,
		an empty array will be returned.

		Enabling `preventRepeats` will filter out any repeated argument
		combos that have the same types. For example, if a function
		as two `String` optional arguments, it has four possible combos;
		however, two of those combos are just one argument of type
		`String` being passed. This would filter that and provide
		only three variations: (), (`String`), (`String`, `String`).
	**/
	public function findAllArgumentVariations(frontOptionalsOnly: Bool = false, preventRepeats: Bool = false): Array<{ args: Array<ClassFuncArg>, padExprs: Array<TypedExpr> }> {
		// Find latest require argument if `frontOptionalsOnly`.
		//
		// Required and optional arguments can be mixed infinitely, so the first required
		// argument does not guaretee all "front optionals" have been found.
		// i.e: in `function(?a, b, ?c, d, ?e)`, "a" and "c" are front optionals.
		final end = if(frontOptionalsOnly) {
			var latestRequired = -1;
			for(i in 0...args.length) {
				if(!args[i].opt) {
					latestRequired = i;
				}
			}
			latestRequired;
		} else {
			args.length;
		}

		// If every argument is optional and `frontOptionalsOnly`, there are no variations.
		if(end == -1) {
			return [];
		}

		// Iterate again to find all the optional indexes.
		final optionalIndexes = [];
		for(i in 0...end) {
			if(args[i].opt) {
				optionalIndexes.push(i);
			}
		}

		// If there are no optional arguments, there is only one possibility.
		if(optionalIndexes.length == 0) {
			return [{ args: args, padExprs: args.map(a -> TypedExprHelper.make(TIdent(a.name), a.type)) }];
		}

		// Find every variation by determining the max number of combinations (2^optional_count),
		// then generate each one using the binary for every number from 0 to the max number.
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

		// Filter out any repeats if they exist.
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
