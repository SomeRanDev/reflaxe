// =======================================================
// * ClassModifier
// =======================================================

package reflaxe.input;

#if (macro || reflaxe_runtime)

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

/**
	Sometimes a class or function needs to be modified 
	before the Haxe typing phase for your target.

	This class can be used in an initialization macro
	to set up` @:build` macros to modify a desired function.
**/
class ClassModifier {
	static var modifications: Map<String, Map<String, Expr>> = [];

	public static function mod(classPath: String, functionName: String, newExpr: Expr): Void {
		if(!modifications.exists(classPath)) {
			modifications.set(classPath, []);

			#if eval
			Compiler.addMetadata("@:build(reflaxe.input.ClassModifier.applyMod(\"" + classPath + "\"))", classPath);
			#end
		}

		final m = modifications[classPath];
		if(m != null) {
			m.set(functionName, newExpr);
		}
	}

	public static function applyMod(classPath: String): Null<Array<Field>> {
		#if eval
		final fields = Context.getBuildFields();
		final mods = modifications[classPath];

		for(i in 0...fields.length) {
			final f = fields[i];
			if(mods.exists(f.name)) {
				switch(f.kind) {
					case FFun(fun): {
						fun.expr = mods[f.name];
					}
					case _:
				}
			}
		}

		return fields;
		#else
		return [];
		#end
	}
}

#end
