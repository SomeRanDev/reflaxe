// =======================================================
// * ClassHiearchyTracker
// =======================================================

package reflaxe.input;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.TypeTools;

import reflaxe.data.ClassFuncData;

using reflaxe.helpers.ArrayHelper;
using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.ClassFieldHelper;
using reflaxe.helpers.ClassTypeHelper;
using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NullHelper;
using reflaxe.helpers.TypeHelper;

/**
	Private helper class to store information
	for `ClassType`s when necessary.
**/
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

/**
	Class used to track the hiearchy of classes.

	Provides a bunch of helpful functions to move up or
	down the class hierarchy that aren't usually possible
	from a normal `ClassType`.

	For example, given a `ClassType`, all of the child
	classes that extend or implement it can be found.

	The `trackClassHierarchy` option must be enabled in the
	`BaseCompiler` for this class's functions to work.
**/
class ClassHierarchyTracker {
	public static var initialized(default, null): Bool = false;

	static var classData: Map<String, ClassHierarchyClassData> = [];

	/**
		Returns an array of all the class types that directly "extends"
		or "implements" the provided `ClassType` cls.
	**/
	public static function getAllDirectChildClasses(cls: Null<ClassType>): Array<ClassType> {
		if(!initialized)
			throw "The `trackClassHierarchy` option must be enabled to use this `ClassHierarchyTracker` function.";

		if(cls == null)
			return [];

		final name = cls.globalName();
		final data = classData.get(name);
		return if(data != null) {
			data.children;
		} else {
			[];
		}
	}

	/**
		Returns an array that recursively finds every class that descends
		from the provided `ClassType`. This includes all the direct children,
		the children of the children, and the children of those, etc.
	**/
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

	/**
		Returns the chain of parent classes from the ClassType.
		The array is ordered by distance. The first element is the super
		class of `cls`, the second the super class of that, etc.
	**/
	public static function getAllParentClasses(cls: ClassType): Array<ClassType> {
		return if(cls.superClass != null) {
			final superClass = cls.superClass.t.get();
			[superClass].concat(getAllParentClasses(superClass));
		} else {
			[];
		}
	}

	/**
		Similar to `getAllParentClasses`, but returns the parent classes as `Type`s.
		The `Type`s are guarenteed to be `TInst`.
		
		The advantage to this function is it retains type parameter data relative to
		the input class' `TypeParameter`s. For example, if "Child" from the following
		example is provided, this function will return the equivalent of:
		`[ Base<Child.T>, TopClass<String> ]`
		
		```haxe
		class TopClass<A> {}
		class Base<B> extends TopClass<String> {}
		class Child<T> extends Base<T> {}
		```
	**/
	public static function getAllParentTypes(cls: ClassType, params: Null<Array<Type>> = null, resultArray: Null<Array<Type>> = null): Array<Type> {
		return #if macro if(cls.superClass != null) {
			final clsRef = cls.superClass.t;
			if(params == null) {
				params = cls.params.map(c -> c.t);
			}
			final newParams = cls.superClass.params;
			final superClass = TypeTools.applyTypeParameters(TInst(clsRef, newParams), cls.params, params);

			if(resultArray == null) resultArray = [];

			resultArray.push(superClass);
			getAllParentTypes(clsRef.get(), newParams, resultArray);

			resultArray;
		} else #end {
			[];
		}
	}

	/**
		Returns every interface implemented to this class and all parent classes.
		Repeats are ignored.
	**/
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

	/**
		Same as `getAllParentTypes`, only works on the interfaces for the class'
		hierarchy.

		TODO: Repeat interfaces are no longer checked (they never were to begin with technically). Should it be fixed??
	**/
	public static function getAllParentInterfaceTypes(cls: ClassType, params: Null<Array<Type>> = null, resultArray: Null<Array<Type>> = null): Array<Type> {
		if(params == null) {
			params = cls.params.map(c -> c.t);
		}

		if(resultArray == null) resultArray = [];

		for(int in cls.interfaces) {
			resultArray.push(
				#if macro
				TypeTools.applyTypeParameters(TInst(int.t, int.params), cls.params, params)
				#else
				TInst(int.t, int.params)
				#end
			);
		}

		if(cls.superClass != null) {
			getAllParentInterfaceTypes(cls.superClass.t.get(), cls.superClass.params, resultArray);
		}

		return resultArray;
	}

	/**
		Given a super class `ClassType`, checks all the children to
		see if the given function field `superClassField` is ever
		overriden.
		
		Useful for cases where a function must be explicitly marked
		as overridable in the parent.
	**/
	public static function funcHasChildOverride(superClass: ClassType, superClassField: ClassField, isStatic: Bool): Bool {
		for(child in getAllChildClasses(superClass)) {
			if(getFieldsOfName(child, superClassField.name) != null) {
				return true;
			}
		}
		return false;
	}

	/**
		Given a child class `ClassType` and its function `ClassField`, return true if
		the return type of the function is covariant. (aka. the return type is a child
		of the return type of the equivalent function in a super class or interface).
	**/
	public static function childFuncIsCovariant(childClass: ClassType, childClassField: ClassField, isStatic: Bool): Bool {
		return funcGetCovariantBaseType(childClass, childClassField, isStatic) != null;
	}

	/**
		Returns every super class and implemented interface of this class as a `Type`.
	**/
	public static function getAllParentTypesAndInterfaces(childClass: ClassType): Array<Type> {
		final result = getAllParentTypes(childClass);
		result.reverse();

		getAllParentInterfaceTypes(childClass, null, result);

		return result;
	}

	/**
		Used by `getFieldsOfName`.
		TODO: Change to local static once those start working.
	**/
	static var getFieldsOfName_cache: Map<String, Map<String, Array<ClassField>>> = [];

	/**
		Finds all fields of a `ClassType` that have a specific name.
		Uses a cache to re-retrieve the data faster.
	**/
	static function getFieldsOfName(cls: ClassType, fieldName: String): Null<Array<ClassField>> {
		final uniqueClassId = cls.pack.joinAppend(".") + cls.name;

		if(!getFieldsOfName_cache.exists(uniqueClassId)) {
			final fieldMap: Map<String, Array<ClassField>> = [];
			function add(field) {
				var arr = fieldMap.get(field.name);
				if(arr == null) {
					arr = [];
					fieldMap.set(field.name, arr);
				}
				arr.push(field);
			}
			for(field in cls.statics.get()) add(field);
			for(field in cls.fields.get()) add(field);
			getFieldsOfName_cache.set(uniqueClassId, fieldMap);
		}

		return getFieldsOfName_cache.get(uniqueClassId).trustMe().get(fieldName);
	}

	/**
		If the return type of `ClassField` "childClassField" is covariant (aka. the
		function is overriding a parent's function but using a child of the parent's
		function's return type), then this function returns the parent function's
		return type.
	**/
	public static function funcGetCovariantBaseType(childClass: ClassType, childClassField: ClassField, isStatic: Bool): Null<Type> {
		final childData = childClassField.findFuncData(childClass);

		for(p in getAllParentTypesAndInterfaces(childClass)) {
			final decl = switch(p) {
				case TInst(clsRef, params): { cls: clsRef.get(), params: params };
				case _: throw "Impossible";
			}

			final possibleFields = getFieldsOfName(decl.cls, childClassField.name);
			if(possibleFields == null) {
				continue;
			}

			for(field in possibleFields) {
				if(isCovariant(field.findFuncData(decl.cls), childData)) {
					#if macro
					return TypeTools.applyTypeParameters(field.type.getTFunReturn(), decl.cls.params, decl.params);
					#else
					return field.type.getTFunReturn();
					#end
				}
			}
		}

		return null;
	}

	/**
		Given a child class' type and field information, returns `true` if
		the provided `childClassField` is a covariant field.
	**/
	public static function funcIsCovariant(childClass: ClassType, childClassField: ClassField, isStatic: Bool): Bool {
		return funcGetCovariantBaseType(childClass, childClassField, isStatic) != null;
	}

	/**
		Does the same as `childFuncIsCovariant`, but checks "downwards".

		Checks if any children of the supplied "superClass" `ClassType` override
		this class's functions and use a covariant return type.
	**/
	public static function superFuncIsCovariant(superClass: ClassType, superClassField: ClassField, isStatic: Bool): Bool {
		final superFieldData = superClassField.findFuncData(superClass);
		for(child in getAllChildClasses(superClass)) {
			final possibleFields = getFieldsOfName(child, superClassField.name);
			if(possibleFields == null) continue;
			for(field in possibleFields) {
				if(isCovariant(superFieldData, field.findFuncData(child))) {
					return true;
				}
			}
		}
		return false;
	}

	/**
		Given a field and its equivalent child version, returns true if it's
		a function with a covariant return type.
	**/
	static function isCovariant(superField: Null<ClassFuncData>, childField: Null<ClassFuncData>): Bool {
		if(superField == null || childField == null) {
			return false;
		}
		if(!isOverride(superField, childField)) {
			return false;
		}
		var superFieldRet = superField.field.type.getTFunReturn();
		var childFieldRet = childField.field.type.getTFunReturn();
		if(superFieldRet == null || childFieldRet == null) {
			return false;
		}
		#if eval
		superFieldRet = Context.follow(superFieldRet);
		childFieldRet = Context.follow(childFieldRet);
		#end
		if(superFieldRet.isTypeParameter() || childFieldRet.isTypeParameter()) {
			return false;
		}
		return Std.string(superFieldRet) != Std.string(childFieldRet);
	}

	/**
		Given a field and its equivalent child version, returns true if the
		child field overrides the super field.
	**/
	static function isOverride(superField: ClassFuncData, childField: ClassFuncData): Bool {
		if(superField.field.name != childField.field.name) {
			return false;
		}

		// If there are no overloads, they must be overrides since they have the same name.
		if(superField.field.overloads.get().length == 0 && childField.field.overloads.get().length == 0) {
			return true;
		}

		return superField.argumentsMatch(childField);
	}

	/**
		Given a `ClassFuncData` superField, this function finds all the functions
		contained within children that override this field.
	**/
	public static function findAllChildOverrides(superField: ClassFuncData): Array<ClassFuncData> {
		final result: Array<ClassFuncData> = [];
		for(child in getAllChildClasses(superField.classType)) {
			final possibleFields = getFieldsOfName(child, superField.field.name);
			if(possibleFields == null) continue;
			for(field in possibleFields) {
				final data = field.findFuncData(child);
				if(data != null && isOverride(superField, data)) {
					result.push(data);
				}
			}
		}
		return result;
	}

	/**
		Given a `ClassFuncData` childField, this function returns the chain of
		super class functions this field overrides.
	**/
	public static function getParentOverrideChain(childField: ClassFuncData): Array<ClassFuncData> {
		final result: Array<ClassFuncData> = [];
		for(parent in getAllParentTypesAndInterfaces(childField.classType)) {
			final decl = switch(parent) {
				case TInst(clsRef, params): { cls: clsRef.get(), params: params };
				case _: throw "Impossible";
			}

			for(field in decl.cls.fields.get()) {
				final data = field.findFuncDataFromType(parent);
				if(data != null && isOverride(data, childField)) {
					result.push(data);
				}
			}
		}
		return result;
	}

	/**
		Works like `getParentOverrideChain` but doesn't include interfaces and
		abstract functions.
	**/
	public static function getParentOverrideChainNoAbstracts(childField: ClassFuncData): Array<ClassFuncData> {
		final result: Array<ClassFuncData> = [];
		for(parent in getAllParentTypes(childField.classType)) {
			final decl = switch(parent) {
				case TInst(clsRef, params): { cls: clsRef.get(), params: params };
				case _: throw "Impossible";
			}

			for(field in decl.cls.fields.get()) {
				if(field.isAbstract) continue;
				final data = field.findFuncDataFromType(parent);
				if(data != null && isOverride(data, childField)) {
					result.push(data);
				}
			}
		}
		return result;
	}

	/**
		Tries to check if the function is an `override`.
	**/
	public static function funcIsOverride(childField: ClassFuncData): Bool {
		final chain = getParentOverrideChainNoAbstracts(childField);
		return chain.length > 0;
	}

	/**
		Returns a combined list of `findAllChildOverrides` and `getParentOverrideChain`.
	**/
	public static function findAllOverrides(field: ClassFuncData): Array<ClassFuncData> {
		return getParentOverrideChain(field).concat(findAllChildOverrides(field));
	}

	/**
		In Haxe, it's possible a base class and child class may implement
		the same interface. Depending how the interface is implemented in
		the output language, it may be desirable to only have the base
		class implement the interface.
		
		To help with this, this function returns all the interfaces that
		are not already implemented by any base classes in the provided
		class's hierarchy.
	**/
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

	/**
		Processes all possible `ModuleType`s to be used for compilation.
		Called at the start of compilation to map everything out.
	**/
	public static function processAllClasses(modules: Null<Array<ModuleType>>) {
		if(modules != null) {
			for(mt in modules) {
				processModule(mt);
			}
			initialized = true;
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
