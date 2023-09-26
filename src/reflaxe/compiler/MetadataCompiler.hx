// =======================================================
// * MetadataCompiler
// =======================================================

package reflaxe.compiler;

#if (macro || reflaxe_runtime)

import reflaxe.BaseCompiler;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;

/**
	A class containing the code for compiling metadata.
**/
class MetadataCompiler {
	public static function compileMetadata(options: BaseCompilerOptions, metaAccess: Null<MetaAccess>, target: haxe.display.Display.MetadataTarget): Null<String> {
		if(metaAccess == null) {
			return null;
		}

		final compiledMeta = [];

		if(options.allowMetaMetadata && options.autoNativeMetaFormat != null) {
			final nativeMeta = metaAccess.extractNativeMeta();
			if(nativeMeta != null) {
				for(m in nativeMeta) {
					final tempMeta = StringTools.replace(options.autoNativeMetaFormat, "{}", m);
					compiledMeta.push(tempMeta);
				}
			}
		}

		for(template in options.metadataTemplates) {
			final name = template.meta.metadata;
			final entries = metaAccess.extract(name);

			if(template.disallowMultiple && entries.length > 1) {
				err("'@" + name + "' metadata can only be applied once.", entries[1].pos);
			}

			for(e in entries) {
				if(template.meta.targets != null && !template.meta.targets.contains(target)) {
					err("'@" + name + "' metadata expected to be used on " + template.meta.targets + " only.", e.pos);
				}

				var argsMatch = true;

				if(template.paramTypes != null) {
					final entryArgTypes = (e.params == null ? [] : e.params).map(getMetaArgInputType);
					final paramTypes = template.paramTypes.map(getMetaArgType);

					if(entryArgTypes.length > paramTypes.length) {
						argsMatch = false;
						err("Too many arguments supplied to meta '@" + name + "'.", e.pos);
					}

					for(i in 0...paramTypes.length) {
						var matches = false;
						if(i < entryArgTypes.length) {
							if(paramTypes[i].t == "any" || paramTypes[i].t == entryArgTypes[i]) {
								matches = true;
							}
						}
						if(!matches && paramTypes[i].opt) {
							matches = true;
						}
						if(!matches) {
							argsMatch = false;
							final params = e.params.or([]);
							final pos = i < params.length ? params[i].pos : e.pos;
							err("Metadata argument of type '" + paramTypes[i].t + "' expected.", pos);
						}
					}
				}

				if(argsMatch) {
					if(template.compileFunc != null) {
						final args = (e.params == null ? [] : e.params).map(haxe.macro.ExprTools.toString);
						final result = template.compileFunc(e, args);
						if(result != null) {
							compiledMeta.push(result);
						}
					}
				}
			}
		}

		return if(compiledMeta.length > 0) {
			compiledMeta.join("\n") + "\n";
		} else {
			"";
		}
	}

	static function err(msg: String, pos: Position) {
		#if eval
		Context.error(msg, pos);
		#end
	}

	static function getMetaArgInputType(e: Expr): String {
		return switch(e.expr) {
			case EConst(CInt(_)) | EConst(CFloat(_)): "number";
			case EConst(CString(_, _)): "string";
			case EConst(CIdent("true")) | EConst(CIdent("false")): "bool";
			case EConst(CIdent(_)): "ident";
			case EArrayDecl(_): "array";
			case _: "any";
		}
	}

	static function getMetaArgType(arg: MetaArgumentType): { t: String, opt: Bool } {
		var opt = false;
		var s = (arg : String);
		if(StringTools.endsWith(arg, "?")) {
			opt = true;
			s = s.substring(0, s.length - 2);
		}

		return { t: s, opt: opt };
	}
}


#end
