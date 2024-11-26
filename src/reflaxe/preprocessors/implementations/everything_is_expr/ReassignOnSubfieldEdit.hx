// =======================================================
// * ReassignOnSubfieldEdit
// =======================================================

package reflaxe.preprocessors.implementations.everything_is_expr;

#if (macro || reflaxe_runtime)

import reflaxe.helpers.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;

using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.FieldAccessHelper;
using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.OperatorHelper;
using reflaxe.helpers.TypedExprHelper;

/**
	Implements the @:reassignOnSubfieldEdit feature.

	This is a powerful, unsafe feature that allows for readable
	field manipulation combined with proper setter assignment.

	This is the structure of the metadata.
	@:reassignOnSubfieldEdit(setterName: Ident, ...propertyNames: Ident)

	`Ident` refers to a basic, single-word identifier.

	The first argument "setterName" MUST be a physical field that's a 
	function that takes one argument. The return type can be anything. 

	Here is an example of how it works:

	```haxe
	class Data {
		public function new(x: Int, y: Int) { this.x = x; this.y = y; }
		var x: Int; var y: Int;
	}

	class HolderOfData {
		@:reassignOnSubfieldEdit(set_data, x, y)
		public var data(get, set): Data;

		function get_data(): Data { ... }
		function set_data(v): Data { ... }
	}

	function main() {
		final holder: HolderOfData = ...;

		holder.data.x = 2;

		// Normally, the above would be converted into this:
		holder.get_data().x = 2;

		// But with the metadata, it gets converted into this.
		holder.set_data(new Data(2, holder.get_data().y));
	}
	```
**/
class ReassignOnSubfieldEdit {
	static final META_NAME = ":reassignOnSubfieldEdit";

	public static function checkForROSE(sanitizer: EverythingIsExprSanitizer, op: Binop, leftExpr: TypedExpr, rightExpr: TypedExpr) {
		// obj.get_PROP().SUBFIELD = $rightExpr
		//    check for assignment ^
		if(!op.isAssign()) {
			return null;
		}

		final assignOp = switch(op) {
			case OpAssignOp(newOp): newOp;
			case _: null;
		}

		// Replace left expression with its variable expression.
		var originalLeftExpr = null;
		switch(leftExpr.expr) {
			case TField(e, fa): {
				originalLeftExpr = e;
				switch(e.expr) {
					case TLocal(tvar): {
						final replaceExpr = sanitizer.variables.get(tvar.id);
						if(replaceExpr != null) {
							leftExpr = {
								expr: TField(replaceExpr, fa),
								pos: leftExpr.pos,
								t: leftExpr.t
							}
						}
					}
					case _:
				}
			}
			case _:
		}

		// obj.get_PROP().SUBFIELD = $rightExpr
		// ^^^^^^^^^^^^^^ Gets call expression and "SUBFIELD" `FieldAccess`.
		var subfieldAccess = null;
		final getCallExpr = switch(leftExpr.expr) {
			case TField(getCallExpr, _subfieldAccess): {
				subfieldAccess = _subfieldAccess;
				getCallExpr;
			}
			default: return null;
		}

		// obj.get_PROP().SUBFIELD = $rightExpr
		// ^^^^^^^^^^^^ Gets "getter" field expression without call.
		final getterFieldExpr = switch(getCallExpr.expr) {
			case TCall(getterFieldExpr, []): getterFieldExpr;
			default: return null;
		}

		// obj.get_PROP().SUBFIELD = $rightExpr
		// ^^^^^^^^^^^^ Gets `FieldAccess` and `ClassFuncData` for the "getter".
		final getterFieldAccess = getterFieldExpr.getFieldAccess();
		final getterFuncData = if(getterFieldAccess != null) {
			getterFieldAccess.getFuncData() ?? throw "Impossible";
		} else return null;

		// obj.PROP
		//     ^^^^ Gets the `ClassField` for the property the "getter" wraps.
		final prop: ClassField = if(getterFuncData.isGetter()) {
			getterFuncData.property.trustMe();
		} else return null;

		// Checks for @:reassignOnSubfieldEdit on "PROP" itself.
		if(!prop.hasMeta(META_NAME)) {
			return null;
		}

		// Convert the metadata arguments from identifiers to `String`s.
		final metadataArgs = prop.meta.extractExpressionsFromFirstMeta(META_NAME).map(e -> switch(e.expr) {
			case EConst(CIdent(s)): s;
			case _: Context.error("@:reassignOnSubfieldEdit should only be passed identifiers.", e.pos);
		});

		// Gets the `ClassField` for the "SUBFIELD".
		final subfieldClassField = switch(subfieldAccess) {
			case FInstance(_, _, cf) | FStatic(_, cf): cf;
			case _: throw "Impossible";
		}

		// Make sure the `ClassField`'s name exists in the constructor property list.
		if(!metadataArgs.slice(1).contains(subfieldClassField.get().name)) {
			Context.error("@:reassignOnSubfieldEdit should list all properties", prop.meta.getFirstPosition(META_NAME) ?? prop.pos);
		}

		// Construct!!
		return constructTypedExpr(rightExpr, assignOp, originalLeftExpr ?? getCallExpr, getCallExpr, getterFieldExpr, getterFieldAccess, getterFuncData, subfieldAccess, subfieldClassField.get().name, metadataArgs);
	}

	/**
		Constructs the entire replacement expression.
	**/
	static function constructTypedExpr(
		value: TypedExpr,
		assignOp: Null<Binop>,
		originalLeftExpr: TypedExpr,
		getCallExpr: TypedExpr,
		getterExpr: TypedExpr,
		getterFieldAccess: FieldAccess,
		getterFuncData: ClassFuncData,
		subfieldAccess: FieldAccess,
		modifiedSubfieldName: String,
		metadataArgs: Array<String>
	) {
		final setterName = metadataArgs[0];
		final setFieldAccess = getFieldAccessFromName(setterName, getterFuncData.classType, getterFuncData.isStatic, getterFieldAccess);

		final originalObjectExpr = getterExpr.getFieldAccessExpr();
		if(originalObjectExpr == null) {
			return null;
		}

		return TCall({
			expr: TField(originalObjectExpr, setFieldAccess),
			pos: getterExpr.pos,
			t: getterFuncData.field.type
		}, generateSetterArgument(value, assignOp, originalLeftExpr, getCallExpr, subfieldAccess, modifiedSubfieldName, metadataArgs));
	}

	/**
		Generates a `FieldAccess` by searching through all the fields of the provided `ClassType`.

		The "name" should be the Haxe name.
		The "fa" `FieldAccess` is used to fill the gaps of the new `FieldAccess`.
	**/
	static function getFieldAccessFromName(name: String, classType: ClassType, isStatic: Bool, fa: FieldAccess): FieldAccess {
		for(f in (isStatic ? classType.statics : classType.fields).get()) {
			if(f.getHaxeName() == name) {
				return switch(fa) {
					case FInstance(c, params, _): {
						FInstance(c, params, { get: () -> f, toString: () -> "" });
					}
					case FStatic(c, _): {
						FStatic(c, { get: () -> f, toString: () -> "" });
					}
					case _: throw "Impossible";
				}
			}
		}
		throw "Impossible?";
	}

	static function getClassTypeInfo(type: Type): Array<Dynamic> {
		return switch(type) {
			case TInst(clsRef, params): ([clsRef, params] : Array<Dynamic>);
			case TAbstract(absRef, params): ([getClassTypeInfo(absRef.get().type)[0], params] : Array<Dynamic>);
			case _: throw "Impossible";
		}
	}

	/**
		Generates the single argument passed to the new setter.
	**/
	static function generateSetterArgument(
		value: TypedExpr,
		assignOp: Null<Binop>,
		originalLeftExpr: TypedExpr,
		getCallExpr: TypedExpr,
		subfieldAccess: FieldAccess,
		modifiedSubfieldName: String,
		metadataArgs: Array<String>
	): Array<TypedExpr> {
		// We need to access the `Ref<ClassType>` and its possible params later.
		final info = getClassTypeInfo(getCallExpr.t);

		// Generates the arguments for the constructor in the resulting expression.
		final newArgs = [];
		for(name in metadataArgs.slice(1)) {
			final fa = getFieldAccessFromName(name, info[0].get(), false, subfieldAccess);
			final baseValue = {
				expr: TField(originalLeftExpr, fa),
				pos: originalLeftExpr.pos,
				t: fa.getClassField().trustMe().type
			};
			final arg = if(modifiedSubfieldName == name) {
				if(assignOp == null) {
					value;
				} else {
					{
						expr: TBinop(assignOp, baseValue, value),
						pos: baseValue.pos,
						t: baseValue.t
					};
				}
			} else {
				baseValue;
			}

			newArgs.push(arg);
		}

		// Generate "new" expression for the setter.
		return [
			{
				expr: TNew(info[0], info[1], newArgs),
				pos: getCallExpr.pos,
				t: getCallExpr.t
			}
		];
	}
}

#end
