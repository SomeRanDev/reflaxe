// =======================================================
// * TempVariableNameGenerator
//
// When converting from "Everything is an Expression" syntax,
// new variables need to be introduced. 
//
// In an attempt to keep the variables names unique/consistent
// (but also look like they were written by a human), this class
// is used to construct and manage the variable names.
//
// It is used exclusively in "optimization/EverythingIsExprConversion.hx"
// So check out that file for more information.
// =======================================================

package reflaxe.optimization;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

class TempVariableNameGenerator {
	// -------------------------------------------------------
	// Count how many times a variable name is used so if it's
	// used again we can append a "2", "3", etc. to keep it unique.
	var variableNameCounts: Map<String, Int> = [];

	public function new() {
	}

	// -------------------------------------------------------
	// Generate variable name based on the type
	public function generateName(t: Null<Type>, baseNameOverride: Null<String> = null) {
		final baseName = baseNameOverride != null ? baseNameOverride : generateBaseName(t);
		final count = if(variableNameCounts.exists(baseName)) {
			variableNameCounts.get(baseName);
		} else {
			0;
		}

		final result = makeName(baseName, count);

		variableNameCounts.set(baseName, count + 1);

		return result;
	}

	// -------------------------------------------------------
	// The "base" name if the type cannot be determined
	public function unknownBaseTypeName(): String {
		return "var";
	}

	// -------------------------------------------------------
	// Generate name from the base and number of uses
	public function makeName(baseName: String, count: Int) {
		final base = baseName.substring(0, 1).toUpperCase() + baseName.substring(1).toLowerCase();
		final suffix = (count > 0 ? Std.string(count) : "");
		return "temp" + base + suffix;
	}

	// -------------------------------------------------------
	// Get the "base" name of the variable using type.
	// tempTYPENAME123 - etc: tempNum, tempString3, tempFunction2
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
			case TAbstract(abstractTypeRef, _): {
				switch(abstractTypeRef.get().name) {
					case "Int" | "Float": "number";
					case "String": "string";
					case s: s;
				}
			}
		}
	}
}

#end
