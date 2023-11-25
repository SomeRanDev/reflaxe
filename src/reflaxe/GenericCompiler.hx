package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;
import reflaxe.output.DataAndFileInfo;
import reflaxe.output.PluginHook;

using reflaxe.helpers.NullHelper;

/**
	Used to store the compiled data and its metadata.
**/
typedef CompiledCollection<T> = Array<DataAndFileInfo<T>>;

/**
	The compiler that allows for custom types to be used as returns for
	the `compiledXImpl` functions.
**/
abstract class GenericCompiler<
	CompiledClassType,
	CompiledEnumType,
	CompiledExpressionType,
	CompiledTypedefType = {},
	CompiledAbstractType = {}
> extends BaseCompiler {
	// =======================================================
	// * Abstract Functions
	//
	// Override in custom compiler to control it.
	// =======================================================
	public abstract function compileClassImpl(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<CompiledClassType>;
	public abstract function compileEnumImpl(enumType: EnumType, options: Array<EnumOptionData>): Null<CompiledEnumType>;
	public abstract function compileExpressionImpl(expr: TypedExpr, topLevel: Bool): Null<CompiledExpressionType>;

	public function compileTypedefImpl(typedefType: DefType): Null<CompiledTypedefType> {
		return null;
	}

	public function compileAbstractImpl(abstractType: AbstractType): Null<CompiledAbstractType> {
		return null;
	}

	// =======================================================
	// * Compiled Data
	//
	// The data stored from compiling from Haxe typed AST.
	// =======================================================
	var classes: CompiledCollection<CompiledClassType> = [];
	var enums: CompiledCollection<CompiledEnumType> = [];
	var typedefs: CompiledCollection<CompiledTypedefType> = [];
	var abstracts: CompiledCollection<CompiledAbstractType> = [];

	/**
		Generates `CompiledCollection` from a generic object and `BaseType`.
	**/
	function generateCompiledCollection<T>(compiledObject: T, baseType: BaseType): DataAndFileInfo<T> {
		final result = new DataAndFileInfo<T>(compiledObject, baseType, fileNameOverride, fileDirOverride);

		// Reset these for next time
		fileNameOverride = null;
		fileDirOverride = null;

		return result;
	}

	/**
		Compiles the provided class.
		Override `compileClassImpl` to configure the behavior.
	**/
	public function compileClass(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>) {
		final data = {
			#if reflaxe_hooks
			final hookResult = compileClassHook.call(null, this, classType, varFields, funcFields);
			if(!hookResult.isIgnore()) {
				switch(hookResult) {
					case OverwriteOutput(output): output;
					case _: null;
				}
			} else
			#end

			compileClassImpl(classType, varFields, funcFields);
		}
		if(data != null) classes.push(generateCompiledCollection(data.trustMe(), classType));
	}

	/**
		Compiles the provided enum.
		Override `compileEnumImpl` to configure the behavior.
	**/
	public function compileEnum(enumType: EnumType, options: Array<EnumOptionData>) {
		final data = {
			#if reflaxe_hooks
			final hookResult = compileEnumHook.call(null, this, enumType, options);
			if(!hookResult.isIgnore()) {
				switch(hookResult) {
					case OverwriteOutput(output): output;
					case _: null;
				}
			} else
			#end

			compileEnumImpl(enumType, options);
		}
		if(data != null) enums.push(generateCompiledCollection(data.trustMe(), enumType));
	}

	/**
		Compiles the provided typedef.
		Override `compileTypedefImpl` to configure the behavior.
	**/
	public function compileTypedef(typedefType: DefType) {
		final data = {
			#if reflaxe_hooks
			final hookResult = compileTypedefHook.call(null, this, typedefType);
			if(!hookResult.isIgnore()) {
				switch(hookResult) {
					case OverwriteOutput(output): output;
					case _: null;
				}
			} else
			#end

			compileTypedefImpl(typedefType);
		}
		if(data != null) typedefs.push(generateCompiledCollection(data.trustMe(), typedefType));
	}

	/**
		Compiles the provided abstract.
		Override `compileAbstractImpl` to configure the behavior.
	**/
	public function compileAbstract(abstractType: AbstractType) {
		final data = {
			#if reflaxe_hooks
			final hookResult = compileAbstractHook.call(null, this, abstractType);
			if(!hookResult.isIgnore()) {
				switch(hookResult) {
					case OverwriteOutput(output): output;
					case _: null;
				}
			} else
			#end

			compileAbstractImpl(abstractType);
		}
		if(data != null) abstracts.push(generateCompiledCollection(data.trustMe(), abstractType));
	}

	/**
		Compiles the provided expression.
		Override `compileExpressionImpl` to configure the behavior.
	**/
	public function compileExpression(expr: TypedExpr, topLevel: Bool = false): Null<CompiledExpressionType> {
		#if reflaxe_hooks
		final hookResult = compileBeforeExpressionHook.call(null, this, expr, topLevel);
		switch(hookResult) {
			case IgnorePlugin:
			case OutputNothing: return null;
			case OverwriteOutput(output): return output;
		}
		#end

		final result = compileExpressionImpl(expr, topLevel);

		#if reflaxe_hooks
		final hookResult = compileExpressionHook.call(result, this, expr, topLevel);
		switch(hookResult) {
			case IgnorePlugin:
			case OutputNothing: return null;
			case OverwriteOutput(output): return output;
		}
		#end

		return result;
	}

	/**
		Compiles the provided expression.
		Generates an error using `Context.error` if unsuccessful.
	**/
	public function compileExpressionOrError(expr: TypedExpr): CompiledExpressionType {
		final result = compileExpression(expr, false);
		if(result == null) {
			return onExpressionUnsuccessful(expr.pos);
		}
		return result;
	}

	// =======================================================
	// * Hooks System
	//
	// If `-D reflaxe_hooks` is defined, callbacks can be
	// assigned using these fields to configure custom
	// output for a Reflaxe target's generated content.
	// =======================================================
	#if reflaxe_hooks
	public var compileClassHook(default, null)            = new PluginHook4<CompiledClassType, BaseCompiler, ClassType, Array<ClassVarData>, Array<ClassFuncData>>();
	public var compileEnumHook(default, null)             = new PluginHook3<CompiledEnumType, BaseCompiler, EnumType, Array<EnumOptionData>>();
	public var compileTypedefHook(default, null)          = new PluginHook2<CompiledTypedefType, BaseCompiler, DefType>();
	public var compileAbstractHook(default, null)         = new PluginHook2<CompiledAbstractType, BaseCompiler, AbstractType>();
	public var compileExpressionHook(default, null)       = new PluginHook3<CompiledExpressionType, BaseCompiler, TypedExpr, Bool>();
	public var compileBeforeExpressionHook(default, null) = new PluginHook3<CompiledExpressionType, BaseCompiler, TypedExpr, Bool>();
	#end
}

#end
