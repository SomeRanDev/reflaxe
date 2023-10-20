package reflaxe;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

import reflaxe.GenericCompiler;
import reflaxe.compiler.TargetCodeInjection;
import reflaxe.optimization.ExprOptimizer;
import reflaxe.output.DataAndFileInfo;

import reflaxe.output.StringOrBytes;

using StringTools;

using reflaxe.helpers.TypedExprHelper;
using reflaxe.helpers.TypeHelper;

/**
	An extended version of the `GenericCompiler` that uses `String` for all
	the "compile" function return types.
**/
abstract class DirectToStringCompiler extends GenericCompiler<String, String, String, String, String> {
	/**
		Overridden to add target-code injection support.
	**/
	public override function compileExpression(expr: TypedExpr, topLevel: Bool = false): Null<String> {
		if(options.targetCodeInjectionName != null) {
			final result = TargetCodeInjection.checkTargetCodeInjection(options.targetCodeInjectionName, expr, this);
			if(result != null) {
				return result;
			}
		}

		return compileExpressionImpl(expr, topLevel);
	}

	/**
	Iterate through all output `String`s.
	**/
	public function generateOutputIterator(): Iterator<DataAndFileInfo<StringOrBytes>> {
		final all: CompiledCollection<String> = classes.concat(enums).concat(typedefs).concat(abstracts);
		var index = 0;
		return {
			hasNext: () -> index < all.length,
			next: () -> {
				final data = all[index++];
				return data.withOutput(data.data);
			}
		};
	}

	/**
		Returns the result of calling "ExprOptimizer.optimizeAndUnwrap"
		and "compileExpressionsIntoLines" from the "expr".
	**/
	public function compileClassVarExpr(expr: TypedExpr): String {
		final exprs = ExprOptimizer.optimizeAndUnwrap(expr);
		return compileExpressionsIntoLines(exprs);
	}

	/**
		Same as "compileClassVarExpr", but also uses 
		EverythingIsExprSanitizer if required.
	**/
	public function compileClassFuncExpr(expr: TypedExpr): String {
		return compileClassVarExpr(expr);
	}

	/**
		Convert a list of expressions to lines of output code.
		The lines of code are spaced out to make it feel like
		it was human-written.
	**/
	public function compileExpressionsIntoLines(exprList: Array<TypedExpr>): String {
		var currentType = -1;
		final lines = [];

		injectionAllowed = true;

		for(e in exprList) {
			final newType = expressionType(e);
			if(currentType != newType) {
				if(currentType != -1) lines.push("");
				currentType = newType;
			}

			// Compile expression
			final output = compileExpression(e, true);

			// Add injections
			final preExpr = prefixExpressionContent(e, output);
			if(preExpr != null) {
				for(e in preExpr) {
					lines.push(formatExpressionLine(e));
				}
			}

			// Add compiled expression
			if(output != null) {
				lines.push(formatExpressionLine(output));
			}

			// Clear injection list
			if(injectionContent.length > 0) {
				injectionContent = [];
			}
		}

		injectionAllowed = false;

		return lines.join("\n");
	}

	/**
		Allows for content to be injected before an expression.
		Useful for adding call stack information to output.
	**/
	function prefixExpressionContent(expr: TypedExpr, output: Null<String>): Null<Array<String>> {
		return injectionContent.length > 0 ? injectionContent : null;
	}

	/**
		Stores a list of content to be injected between expressions.
		See `injectExpressionPrefixContent` for implementation.
	**/
	var injectionContent: Array<String> = [];

	/**
		Tracks whether content can be injected while compiling
		an expression.
	**/
	var injectionAllowed: Bool = false;

	/**
		If called while compiling multiple expressions, this
		will inject content prior to the expression currently
		being compiled.
	**/
	public function injectExpressionPrefixContent(content: String): Bool {
		return if(injectionAllowed) {
			injectionContent.push(content);
			true;
		} else {
			false;
		}
	}

	/**
		Called for each line generated in the above function
		"compileExpressionsIntoLines". Useful for adding
		required termination characters for expressions that
		are not treated as values (i.e: semicolons).
	**/
	function formatExpressionLine(expr: String): String {
		return expr;
	}

	/**
		Compiles the {this} expression for `@:nativeFunctionCode`.
	**/
	public function compileNFCThisExpression(expr: TypedExpr, meta: Null<MetaAccess>): String {
		return compileExpressionOrError(expr); 
	}

	/**
		This function is for compiling the result of functions
		using the `@:nativeFunctionCode` meta.
	**/
	public function compileNativeFunctionCodeMeta(callExpr: TypedExpr, arguments: Array<TypedExpr>, typeParams: Null<Array<() -> String>> = null, custom: Null<(String) -> String> = null): Null<String> {
		final declaration = callExpr.getDeclarationMeta(arguments);
		if(declaration == null) {
			return null;
		}
		final meta = declaration.meta;
		final data = meta != null ? extractStringFromMeta(meta, ":nativeFunctionCode") : null;
		if(data != null) {
			final code = data.code;
			var result = code;

			if(code.contains("{this}")) {
				final thisExpr = declaration.thisExpr != null ? compileNFCThisExpression(declaration.thisExpr, declaration.meta) : null;
				if(thisExpr == null) {
					if(declaration.thisExpr == null) {
						#if eval
						Context.error("Cannot use {this} on @:nativeFunctionCode meta for constructors.", data.entry.pos);
						#end
					} else {
						onExpressionUnsuccessful(callExpr.pos);
					}
				} else {
					result = result.replace("{this}", thisExpr);
				}
			}

			var argExprs: Null<Array<String>> = null;
			for(i in 0...arguments.length) {
				final key = "{arg" + i + "}";
				if(code.contains(key)) {
					if(argExprs == null) {
						argExprs = arguments.map(function(e) {
							return this.compileExpressionOrError(e);
						});
					}
					if(argExprs[i] == null) {
						onExpressionUnsuccessful(arguments[i].pos);
					} else {
						result = result.replace(key, argExprs[i]);
					}
				}
			}

			if(typeParams != null) {
				for(i in 0...typeParams.length) {
					final key = "{type" + i + "}";
					if(code.contains(key)) {
						result = result.replace(key, typeParams[i]());
					}
				}
			}

			if(custom != null) {
				result = custom(result);
			}

			return result;
		}

		return null;
	}

	/**
		This function is for compiling the result of functions
		using the `@:nativeVariableCode` meta.
	**/
	public function compileNativeVariableCodeMeta(fieldExpr: TypedExpr, varCpp: Null<String> = null): Null<String> {
		final declaration = fieldExpr.getDeclarationMeta();
		if(declaration == null) {
			return null;
		}
		final meta = declaration.meta;
		final data = meta != null ? extractStringFromMeta(meta, ":nativeVariableCode") : null;
		if(data != null) {
			final code = data.code;
			var result = code;

			if(code.contains("{this}")) {
				final thisExpr = declaration.thisExpr != null ? compileNFCThisExpression(declaration.thisExpr, declaration.meta) : null;
				if(thisExpr == null) {
					if(declaration.thisExpr == null) {
						#if eval
						Context.error("Cannot use {this} on @:nativeVariableCode meta for constructors.", data.entry.pos);
						#end
					} else {
						onExpressionUnsuccessful(fieldExpr.pos);
					}
				} else {
					result = result.replace("{this}", thisExpr);
				}
			}

			if(varCpp != null && code.contains("{var}")) {
				result = result.replace("{var}", varCpp);
			}

			return result;
		}

		return null;
	}

	/**
		This function is for compiling the result of functions
		using the `@:nativeTypeCode` meta.
	**/
	public function compileNativeTypeCodeMeta(type: Type, typeParams: Null<Array<() -> String>> = null): Null<String> {
		final meta = type.getMeta();
		if(meta == null) {
			return null;
		}

		final data = extractStringFromMeta(meta, ":nativeTypeCode");
		if(data != null) {
			final code = data.code;
			var result = code;

			if(typeParams != null) {
				for(i in 0...typeParams.length) {
					final key = "{type" + i + "}";
					if(code.contains(key)) {
						result = result.replace(key, typeParams[i]());
					}
				}
			}

			return result;
		}

		return null;
	}
}

#end
