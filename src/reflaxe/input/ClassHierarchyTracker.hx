// =======================================================
// * ClassHiearchyTracker
//
// Class used to track the hiearchy of classes.
//
// Provides a bunch of helpful functions to move up or
// down the class hierarchy that aren't usually possible
// from a normal `ClassType`.
//
// For example, given a `ClassType`, all of the child
// classes that extend or implement it can be found.
//
// The `trackClassHierarchy` option must be enabled in the
// `BaseCompiler` for this class's functions to work.
// =======================================================

package reflaxe.input;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.TypeTools;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.TypeHelper;

// Private helper class to store information
// for `ClassType`s when necessary.
final class ClassHierarchyClassData {
	public var cls: ClassType;
	public var children: Array<ClassType>;

	public function new(cls: ClassType) {
		this.cls = cls;
		children = [];
	}

	public function addChild(c: ClassType) {
		if(!children.contains(c)) {
			children.push(c);
		}
	}
}

class ClassHierarchyTracker {
	static var classData: Map<String, ClassHierarchyClassData> = [];

	// Returns an array of all the class types that directly "extends"
	// or "implements" the provided `ClassType` cls.
	public static function getAllDirectChildClasses(cls: Null<ClassType>): Array<ClassType> {
		if(cls == null) return [];
		final name = cls.globalName();
		final data = classData.get(name);
		return if(data != null) {
			data.children;
		} else {
			[];
		}
	}

	// Returns an array that recursively finds every class that descends
	// from the provided ClassType. This includes all the direct children,
	// the children of the children, and the children of those, etc.
	public static function getAllChildClasses(cls: ClassType): Array<ClassType> {
		final result = [];
		for(c in getAllDirectChildClasses(cls)) {
			if(!result.contains(c)) {
				result.push(c);
			}
			for(cChild in getAllChildClasses(c)) {
				if(!result.contains(cChild)) {
					result.push(cChild);
				}
			}
		}
		return result;
	}

	// Returns the chain of parent classes from the ClassType.
	// The array is ordered by distance. The first element is the super
	// class of `cls`, the second the super class of that, etc.
	public static function getAllParentClasses(cls: ClassType): Array<ClassType> {
		return if(cls.superClass != null) {
			final superClass = cls.superClass.t.get();
			[superClass].concat(getAllParentClasses(superClass));
		} else {
			[];
		}
	}

	// Similar to `getAllParentClasses`, but returns the parent classes as `Type`s.
	// The `Type`s are guarenteed to be `TInst`.
	//
	// The advantage to this function is it retains type parameter data relative to
	// the input class' `TypeParameter`s. For example, if "Child" from the following
	// example is provided, this function will return the equivalent of:
	// `[ Base<Child.T>, TopClass<String> ]`
	//
	// class TopClass<A> {}
	// class Base<B> extends TopClass<String> {}
	// class Child<T> extends Base<T> {}
	public static function getAllParentTypes(cls: ClassType, params: Null<Array<Type>> = null): Array<Type> {
		return if(cls.superClass != null) {
			final clsRef = cls.superClass.t;
			if(params == null) {
				params = cls.params.map(c -> c.t);
			}
			final newParams = cls.superClass.params;
			final superClass = TypeTools.applyTypeParameters(TInst(clsRef, newParams), cls.params, params);
			[superClass].concat(getAllParentTypes(clsRef.get(), newParams));
		} else {
			[];
		}
	}

	// Returns every interface implemented to this class and all parent classes.
	// Repeats are ignored.
	public static function getAllParentInterfaces(cls: ClassType): Array<ClassType> {
		final result = cls.interfaces.map(int -> int.t.get());
		if(cls.superClass != null) {
			for(int in getAllParentInterfaces(cls.superClass.t.get())) {
				if(!result.contains(int)) {
					result.push(int);
				}
			}
		}
		return result;
	}

	// Same as `getAllParentTypes`, only works on the interfaces for the class'
	// hierarchy.
	public static function getAllParentInterfaceTypes(cls: ClassType, params: Null<Array<Type>> = null): Array<Type> {
		if(params == null) {
			params = cls.params.map(c -> c.t);
		}

		final result = cls.interfaces.map(function(int) {
			return TypeTools.applyTypeParameters(TInst(int.t, int.params), cls.params, params);
		});

		if(cls.superClass != null) {
			for(int in getAllParentInterfaceTypes(cls.superClass.t.get())) {
				if(!result.contains(int)) {
					result.push(int);
				}
			}
		}

		return result;
	}

	// Given a super class `ClassType`, checks all the children to
	// see if the given function field `superClassField` is ever
	// overriden.
	//
	// Useful for cases where a function must be explicitly marked
	// as overridable in the parent.
	public static function funcHasChildOverride(superClass: ClassType, superClassField: ClassField, isStatic: Bool): Bool {
		for(child in getAllChildClasses(superClass)) {
			for(field in (isStatic ? child.statics.get() : child.fields.get())) {
				if(field.name == superClassField.name) {
					return true;
				}
			}
		}
		return false;
	}

	// Given a child class `ClassType` and its function `ClassField`, return true if
	// the return type of the function is covariant. (aka. the return type is a child
	// of the return type of the equivalent function in a super class or interface).
	public static function childFuncIsCovariant(childClass: ClassType, childClassField: ClassField, isStatic: Bool): Bool {
		return funcGetCovariantBaseType(childClass, childClassField, isStatic) != null;
	}

	// If the return type of `ClassField` "childClassField" is covariant (aka. the
	// function is overriding a parent's function but using a child of the parent's
	// function's return type), then this function returns the parent function's
	// return type.
	public static function funcGetCovariantBaseType(childClass: ClassType, childClassField: ClassField, isStatic: Bool): Null<Type> {
		final parents = getAllParentTypes(childClass);
		parents.reverse();
		for(p in parents.concat(getAllParentInterfaceTypes(childClass))) {
			final decl = switch(p) {
				case TInst(clsRef, params): { cls: clsRef.get(), params: params };
				case _: throw "Impossible";
			}

			for(field in (isStatic ? decl.cls.statics.get() : decl.cls.fields.get())) {
				if(isCovariant(field, childClassField)) {
					return TypeTools.applyTypeParameters(field.type.getTFunReturn(), decl.cls.params, decl.params);
				}
			}
		}

		return null;
	}

	// Does the same as `childFuncIsCovariant`, but checks "downwards".
	// Checks if any children of the supplied "superClass" `ClassType` override
	// this class's functions and use a covariant return type.
	public static function superFuncIsCovariant(superClass: ClassType, superClassField: ClassField, isStatic: Bool): Bool {
		for(child in getAllChildClasses(superClass)) {
			for(field in (isStatic ? child.statics.get() : child.fields.get())) {
				if(isCovariant(superClassField, field)) {
					return true;
				}
			}
		}
		return false;
	}

	// Given a field and its equivalent child version, returns true if it's
	// a function with a covariant return type.
	static function isCovariant(superField: ClassField, childField: ClassField): Bool {
		if(superField.name != childField.name) {
			return false;
		}
		#if eval
		final superFieldRet = Context.follow(superField.type.getTFunReturn());
		final childFieldRet = Context.follow(childField.type.getTFunReturn());
		#else
		final superFieldRet = superField.type.getTFunReturn();
		final childFieldRet = childField.type.getTFunReturn();
		#end
		if(superFieldRet.isTypeParameter() || childFieldRet.isTypeParameter()) {
			return false;
		}
		return Std.string(superFieldRet) != Std.string(childFieldRet);
	}

	// In Haxe, it's possible a base class and child class may implement
	// the same interface. Depending how the interface is implemented in
	// the output language, it may be desirable to only have the base
	// class implement the interface.
	//
	// To help with this, this function returns all the interfaces that
	// are not already implemented by any base classes in the provided
	// class's hierarchy.
	public static function getNonRepeatInterfaces(cls: ClassType): Array<{t: Ref<ClassType>, params: Array<Type>}> {
		if(cls.superClass == null || cls.interfaces.length == 0) {
			return cls.interfaces;
		}

		final result = [];
		for(int in cls.interfaces) {
			final intName = int.t.get().globalName();
			var c = cls;
			var exists = false;
			while(c.superClass != null) {
				c = c.superClass.t.get();
				for(superInt in c.interfaces) {
					if(superInt.t.get().globalName() == intName) {
						exists = true;
						break;
					}
				}
				if(exists) break;
			}
			if(!exists) {
				result.push(int);
			}
		}

		return result;
	}

	// Processes all possible `ModuleType`s to be used for compilation.
	// Called at the start of compilation to map everything out.
	public static function processAllClasses(modules: Null<Array<ModuleType>>) {
		if(modules != null) {
			for(mt in modules) {
				processModule(mt);
			}
		}
	}

	static function processModule(mt: ModuleType) {
		switch(mt) {
			case TClassDecl(clsRef): {
				processClass(clsRef.get());
			}
			case TTypeDecl(defRef): {
				#if eval
				final mt = Context.follow(TypeHelper.fromModuleType(mt)).toModuleType();
				if(mt != null) {
					processModule(mt);
				}
				#end
			}
			case _:
		}
	}

	static function processClass(cls: ClassType) {
		if(cls.isTypeParameter()) return;
		if(cls.superClass != null) {
			addDirectChild(cls.superClass.t.get(), cls);
		}
		for(int in cls.interfaces) {
			addDirectChild(int.t.get(), cls);
		}
	}

	static function addDirectChild(baseCls: Null<ClassType>, childCls: Null<ClassType>) {
		if(baseCls == null) return;
		if(childCls == null) return;

		final id = baseCls.globalName();
		if(!classData.exists(id)) {
			classData.set(id, new ClassHierarchyClassData(baseCls));
		}
		final data = classData.get(id);
		if(data != null) {
			data.addChild(childCls);
		}
	}
}

#end
