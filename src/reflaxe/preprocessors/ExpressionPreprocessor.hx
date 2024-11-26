package reflaxe.preprocessors;

import reflaxe.compiler.NullTypeEnforcer;
import reflaxe.data.ClassFuncData;
import reflaxe.preprocessors.BasePreprocessor;
import reflaxe.preprocessors.implementations.everything_is_expr.EverythingIsExprSanitizer;
import reflaxe.preprocessors.implementations.MarkUnusedVariablesImpl;
import reflaxe.preprocessors.implementations.PreventRepeatVariablesImpl;
import reflaxe.preprocessors.implementations.RemoveConstantBoolIfsImpl;
import reflaxe.preprocessors.implementations.RemoveLocalVariableAliasesImpl;
import reflaxe.preprocessors.implementations.RemoveReassignedVariableDeclarationsImpl;
import reflaxe.preprocessors.implementations.RemoveSingleExpressionBlocksImpl;
import reflaxe.preprocessors.implementations.RemoveTemporaryVariablesImpl;
import reflaxe.preprocessors.implementations.RemoveTemporaryVariablesImpl.RemoveTemporaryVariablesMode;
import reflaxe.preprocessors.implementations.RemoveUnnecessaryBlocksImpl;
import reflaxe.preprocessors.implementations.WrapLambdaCaptureVariablesInArrayImpl;

using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.TypedExprHelper;

/**
	These are processes applied to expressions prior to being passed
	to the user's custom compiler functions.

	Which of these "preprocesses" are used and the order they're used
	in is defined by the `BaseCompilerOptions` `expressionPreprocessors`
	field. View `ExpressionPreprocessorHelper.defaults` to see the default
	list used if left as `null`.

	If you don't know what you're doing, it's recommended these are used
	in the same order they appear in this enum.
**/
@:using(reflaxe.preprocessors.ExpressionPreprocessor.ExpressionPreprocessorHelper)
enum ExpressionPreprocessor {
	/**
		Converts Haxe's "Everything is an Expression" into a more
		compatible format seen in most other programming languages.

		This is a MUST USE for almost all targets.

		For example, this:
		```haxe
		final something = {
			final random = Math.random();
			if(random < 0.5) {
				new Enemy();
			} else {
				new Obstacle();
			}
		}
		```

		Would be converted into this:
		```haxe
		var tempVar;

		{
			final random = Math.random();
			if(random < 0.5) {
				tempVar = new Enemy();
			} else {
				tempVar = new Obstacle();
			}
		}

		final something = tempVar;
		```

		As this can result in more temporary variables than intended, it is
		recommended to combine this with `RemoveTemporaryVariables`.

		This is enabled by default.
	**/
	SanitizeEverythingIsExpression;

	/**
		If `true`, classes marked with `@:prevent_temporaries` will
		regress certain Haxe compiler transformations that
		create unnecessary temporary values.

		This is important for handling value types that should
		be modified in their original location instead of being
		modified on a temporary copy.

		For example, it will prevent this...
		```haxe
		obj.valueTypeInst.prop = 123;
		```

		from being converted to this:
		```haxe
		var temp = obj.valueTypeInst;
		temp.prop = 123;
		```
	**/
	RemoveTemporaryVariables(mode: RemoveTemporaryVariablesMode);

	/**
		Converts repeated variable names into new unique ones.

		This is a MUST USE for target langauges that do not support
		local variable shadowing.

		This is enabled by default.
	**/
	PreventRepeatVariables;

	/**
		Reworks lambda captured variables so they are placed in
		an `Array` and accessed from that within the lambda.

		Useful as certain targets can't capture and modify a value
		unless stored by reference.
	**/
	WrapLambdaCaptureVariablesInArray;

	RemoveSingleExpressionBlocks;
	RemoveConstantBoolIfs;
	RemoveUnnecessaryBlocks;
	RemoveReassignedVariableDeclarations;
	RemoveLocalVariableAliases;
	MarkUnusedVariables;

	/**
		Applies a custom preprocessor.

		The `process` function is called for each processed expression.
	**/
	Custom(preprocessor: BasePreprocessor);
}

/**
	The functions used with `ExpressionPreprocessor`.
**/
class ExpressionPreprocessorHelper {
	/**
		This is where the implementations for the builtin `ExpressionPreprocessor` are.
	**/
	public static function process(self: ExpressionPreprocessor, data: ClassFuncData, compiler: BaseCompiler) {
		if(data.expr == null) {
			return;
		}
		switch(self) {
			case SanitizeEverythingIsExpression: {
				final eiec = new EverythingIsExprSanitizer(data.expr, compiler);
				data.setExpr(eiec.convertedExpr());
				if(eiec.variableUsageCount != null) {
					data.setVariableUsageCount(eiec.variableUsageCount);
				}
			}
			case RemoveTemporaryVariables(mode): {
				final tvr = new RemoveTemporaryVariablesImpl(mode, data.expr, data.getOrFindVariableUsageCount());
				data.setExpr(tvr.fixTemporaries());
			}
			case PreventRepeatVariables: {
				final fieldNames = data.getAllVariableNames(compiler);
				final rvf = new PreventRepeatVariablesImpl(data.expr, null, data.args.map(a -> a.name).concat(fieldNames));
				data.setExpr(rvf.fixRepeatVariables());
			}
			case WrapLambdaCaptureVariablesInArray: {
				final cfv = new WrapLambdaCaptureVariablesInArrayImpl(data.expr);
				data.setExpr(cfv.fixCaptures());
			}
			case RemoveSingleExpressionBlocks: {
				data.setExpr(RemoveSingleExpressionBlocksImpl.process(data.expr));
			}
			case RemoveConstantBoolIfs: {
				data.setExprList(RemoveConstantBoolIfsImpl.process(data.expr.unwrapBlock()));
			}
			case RemoveUnnecessaryBlocks: {
				data.setExprList(RemoveUnnecessaryBlocksImpl.process(data.expr.unwrapBlock()));
			}
			case RemoveReassignedVariableDeclarations: {
				data.setExprList(RemoveReassignedVariableDeclarationsImpl.process(data.expr.unwrapBlock()));
			}
			case RemoveLocalVariableAliases: {
				data.setExprList(RemoveLocalVariableAliasesImpl.process(data.expr.unwrapBlock()));
			}
			case MarkUnusedVariables: {
				data.setExprList(MarkUnusedVariablesImpl.mark(data.expr.unwrapBlock()));
			}
			case Custom(preprocessor): {
				preprocessor.process(data, compiler);
			}
		}
	}

	/**
		The default `ExpressionPreprocessor` list setup.

		This is what is used if `BaseCompilerOptions` `expressionPreprocessors`
		is left as `null`.
	**/
	public static function defaults(): Array<ExpressionPreprocessor> {
		return [
			SanitizeEverythingIsExpression,
			PreventRepeatVariables,
			RemoveSingleExpressionBlocks,
			RemoveConstantBoolIfs,
			RemoveUnnecessaryBlocks,
			RemoveReassignedVariableDeclarations,
			RemoveLocalVariableAliases,
			MarkUnusedVariables,
		];
	}
}
