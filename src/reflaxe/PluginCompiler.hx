// =======================================================
// * PluginCompiler
//
// This class extends from BaseCompiler and should be
// treated as a drop-in replacement for BaseCompiler.
//
// This version of the BaseCompiler adds hooks in
// relevant functions to allow users of your compiler
// to modify and create plugins for it.
// =======================================================

package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.BaseCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.output.PluginHook;

abstract class PluginCompiler<T: BaseCompiler> extends BaseCompiler {
	public var compileClassHook = new PluginHook4<T, ClassType, Array<ClassVarData>, Array<ClassFuncData>>();
	public var compileEnumHook = new PluginHook3<T, EnumType, Array<EnumOptionData>>();
	public var compileTypedefHook = new PluginHook2<T, DefType>();
	public var compileAbstractHook = new PluginHook2<T, AbstractType>();
	public var compileExpressionHook = new PluginHook3<T, TypedExpr, Bool>();
	public var compileBeforeExpressionHook = new PluginHook3<T, TypedExpr, Bool>();

	public override function compileClass(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<String> {
		final result = super.compileClass(classType, varFields, funcFields);
		return compileClassHook.call(result, cast this, classType, varFields, funcFields);
	}

	public override function compileEnum(enumType: EnumType, options: Array<EnumOptionData>): Null<String> {
		final result = super.compileEnum(enumType, options);
		return compileEnumHook.call(result, cast this, enumType, options);
	}

	public override function compileTypedef(classType: DefType): Null<String> {
		final result = super.compileTypedef(classType);
		return compileTypedefHook.call(result, cast this, classType);
	}

	public override function compileAbstract(classType: AbstractType): Null<String> {
		final result = super.compileAbstract(classType);
		return compileAbstractHook.call(result, cast this, classType);
	}

	public override function compileExpression(expr: TypedExpr, topLevel: Bool = false): Null<String> {
		final result = compileBeforeExpressionHook.call(null, cast this, expr, topLevel);
		if(result != null) {
			return result;
		}
		final result = super.compileExpression(expr, topLevel);
		return compileExpressionHook.call(result, cast this, expr, topLevel);
	}
}

#end
