// =======================================================
// * TempVarNameGenerator
// =======================================================

package reflaxe.preprocessors.implementations.everything_is_expr;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

using reflaxe.helpers.NullHelper;

/**
	When converting from "Everything is an Expression" syntax,
	new variables need to be introduced. 

	In an attempt to keep the variables names unique/consistent
	(but also look like they were written by a human), this class
	is used to construct and manage the variable names.

	It is used exclusively in "compiler/EverythingIsExprSanitizer.hx"
	So check out that file for more information.
**/
class TempVarNameGenerator {
	/**
		Count how many times a variable name is used so if it's
		used again we can append a "2", "3", etc. to keep it unique.
	**/
	var variableNameCounts: Map<String, Int> = [];

	public function new() {
	}

	/**
		Reserve names for generation
	**/
	public function reserveNames(names: Array<String>) {
		for(n in names) {
			final count = variableNameCounts.exists(n) ? variableNameCounts.get(n).or(0) : 0;
			variableNameCounts.set(n, count + 1);
		}
	}

	/**
		Generate variable name based on the type
	**/
	public function generateName(t: Null<Type>, baseNameOverride: Null<String> = null) {
		final baseName = baseNameOverride != null ? baseNameOverride : replaceDisallowedCharacters(generateBaseName(t));
		final count = if(variableNameCounts.exists(baseName)) {
			variableNameCounts.get(baseName).or(0);
		} else {
			0;
		}

		final result = makeName(baseName, count);

		variableNameCounts.set(baseName, count + 1);

		return result;
	}

	function replaceDisallowedCharacters(s: String): String {
		return ~/[^0-9a-zA-Z_]+/g.split(s).join("");
	}

	/**
		The "base" name if the type cannot be determined
	**/
	public function unknownBaseTypeName(): String {
		return "var";
	}

	/**
		Generate name from the base and number of uses
	**/
	public function makeName(baseName: String, count: Int) {
		final base = capatalize(baseName);
		final suffix = (count > 0 ? Std.string(count) : "");
		return "temp" + base + suffix;
	}

	function capatalize(s: String) {
		return s.substring(0, 1).toUpperCase() + s.substring(1);
	}

	/**
		Get the "base" name of the variable using type.

		tempTYPENAME123 - etc: tempNum, tempString3, tempFunction2
	**/
	function generateBaseName(t: Null<Type>) {
		return switch(t) {
			case null: unknownBaseTypeName();
			case TMono(typeRef): {
				final t = typeRef.get();
				if(t != null) {
					generateName(t);
				} else {
					unknownBaseTypeName();
				}
			}
			case TEnum(enumTypeRef, _): {
				enumTypeRef.get().name;
			}
			case TInst(classTypeRef, _): {
				classTypeRef.get().name;
			}
			case TType(defTypeRef, _): {
				defTypeRef.get().name;
			}
			case TFun(_, _): {
				"function";
			}
			case TAnonymous(_): {
				"struct";
			}
			case TDynamic(maybeType): {
				if(maybeType != null) {
					generateName(maybeType);
				} else {
					unknownBaseTypeName();
				}
			}
			case TLazy(lazyFunc): {
				generateName(lazyFunc());
			}
			case TAbstract(abstractTypeRef, params): {
				switch(abstractTypeRef.get().name) {
					case "Int" | "Float": "number";
					case "String": "string";
					case "Null": {
						if(params.length > 0) {
							"Maybe" + capatalize(generateBaseName(params[0]));
						} else {
							"Nullable";
						}
					}
					case s: s;
				}
			}
		}
	}
}

#end
