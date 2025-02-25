package reflaxe.data;

#if (macro || reflaxe_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.input.ClassHierarchyTracker;

using reflaxe.helpers.NullableMetaAccessHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypedExprHelper;

class ClassFuncArg {
	public var funcData(default, null): Null<ClassFuncData>;
	public var index(default, null): Int;

	public var type(default, null): Type;
	public var opt(default, null): Bool;
	// DEPRECATED: Use `getName()` instead!! (Or use `originalName`)
	// public var name(default, null): String; // TODO: remove these comments
	public var meta(default, null): Null<MetaAccess>;
	public var expr(default, null): Null<TypedExpr>;
	public var tvar(default, null): Null<TVar>;

	/**
		Stores the original name for the argument.

		This used to be public and named `name`, but you should now use
		`getName()` instead!
	**/
	public var originalName(default, null): String;

	/**
		Replaces the name returned by `getName` if not `null`.
	**/
	public var overrideName(default, null): Null<String>;

	/**
		At the current moment, argument metadata is not retained.
		This system bypasses this problem by extracting `@:argMeta` from the field.
		This metadata is stored here and can be accessed with "metadata" functions.
	**/
	var extraMetadata: Null<Metadata>;

	public function new(index: Int, type: Type, opt: Bool, originalName: String, meta: Null<MetaAccess> = null, expr: Null<TypedExpr> = null, tvar: Null<TVar> = null) {
		this.index = index;

		this.type = type;
		this.opt = opt;
		this.originalName = originalName;
		this.meta = meta;
		this.expr = expr;
		this.tvar = tvar;
	}

	/**
		Assigning the `ClassFuncData` is delayed so the arguments
		can be passed first.
	**/
	public function setFuncData(funcData: ClassFuncData) {
		this.funcData = funcData;
	}

	/**
		Returns `overrideName` if it's not `null`.
		Otherwise, returns `name`.
	**/
	public function getName(): String {
		return if(overrideName != null) {
			overrideName;
		} else {
			originalName;
		}
	}

	/**
		Ensures the value returned by `getName` doesn't match
		any of the provided `names`.
	**/
	public function ensureNameDoesntMatch(names: Array<String>): Bool {
		final currentName = getName();

		var matchFound = false;
		for(name in names) {
			if(currentName == name) {
				overrideName = currentName + "2";
				matchFound = true;
				break;
			}
		}

		if(matchFound) {
			// We need to re-run the check in case any previous names
			// match the new `overrideName`.
			ensureNameDoesntMatch(names);
		}

		return matchFound;
	}

	/**
		Returns true if this argument is optional but doesn't
		have a default value.
	**/
	public function isOptionalWithNoDefault() {
		return opt && expr == null;
	}

	/**
		Returns true if this argument is optional, but there
		are subsequent arguments that are not.
	**/
	public function isFrontOptional() {
		if(!opt) {
			return false;
		}
		final args = funcData.trustMe().args;
		for(i in (index + 1)...args.length) {
			if(!args[i].opt) {
				return true;
			}
		}
		return false;
	}

	/**
		If this argument's function is overriden or is overriding a
		function with a different default value for this argument,
		this returns true.
	**/
	public function hasConflictingDefaultValue(): Bool {
		if(funcData.trustMe().isStatic) {
			return false;
		}

		final overrides = ClassHierarchyTracker.findAllOverrides(funcData.trustMe());
		for(funcData in overrides) {
			if(funcData != null && funcData.args.length > index) {
				final otherDefault = funcData.args[index].expr;

				// check if both have default values
				if(expr != null && otherDefault != null) {
					if(!expr.equals(otherDefault)) {
						return true;
					}
				}

				// check if one has default value but other doesn't
				else if(expr != null || otherDefault != null) {
					return true;
				}
			}
		}
		return false;
	}

	/**
		Convert this class to a String representation.
	**/
	public function toString(): String {
		return (opt ? "?" : "") + originalName + ": " + type + (expr != null ? Std.string(expr) : "");
	}

	public function addExtraMetadata(m: MetadataEntry) {
		if(extraMetadata == null) extraMetadata = [];
		extraMetadata.push(m);
	}

	public function getMetadata(): Null<Metadata> {
		if(meta == null && extraMetadata == null) {
			return null;
		}

		final metadata = meta.maybeGet();
		return if(extraMetadata != null) {
			metadata.concat(extraMetadata);
		} else {
			metadata;
		}
	}

	function findMetadata(name: String): Null<MetadataEntry> {
		final metadata = getMetadata();
		if(metadata == null) return null;
		for(meta in metadata) {
			if(meta.name == name) {
				return meta;
			}
		}
		return null;
	}

	public function hasMetadata(name: String): Bool {
		return findMetadata(name) != null;
	}

	public function getMetadataFirstString(name: String): Null<String> {
		final entryParams = findMetadata(name)?.params;
		if(entryParams != null && entryParams.length > 0) {
			switch(entryParams[0].expr) {
				case EConst(CString(s, _)): return s;
				case _:
			}
		}
		return null;
	}

	public function getMetadataFirstPosition(name: String): Null<Position> {
		final entry = findMetadata(name);
		return entry?.pos;
	}
}

#end
