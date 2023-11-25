// =======================================================
// * PluginHook
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

/**
	The return enum for a `PluginHook`.
**/
enum IPluginHookResult<T> {
	/**
		Does nothing; do the default behavior.
	**/
	IgnorePlugin;

	/**
		Does nothing, but the input does not do the default behavior.
		Instead, the input is ignored by the compiler.
	**/
	OutputNothing;

	/**
		Overwrite the data returned by the compilation.
	**/
	OverwriteOutput(output: T);
}

/**
	Wrapper for the enum return type.
	It can be assigned any type or null.
**/
abstract PluginHookResult<T>(IPluginHookResult<T>) from IPluginHookResult<T> {
	public extern inline function isIgnore() {
		return switch(this) {
			case IgnorePlugin: true;
			case _: false;
		}
	}

	public extern inline function isOutputNothing() {
		return switch(this) {
			case OutputNothing: true;
			case _: false;
		}
	}

	public extern inline function isOverwriteOutput(): Null<T> {
		return switch(this) {
			case OverwriteOutput(output): output;
			case _: null;
		}
	}

	@:from
	public static function fromT<T>(obj: Null<T>): PluginHookResult<T> {
		return if(obj == null) {
			IgnorePlugin;
		} else {
			OverwriteOutput(obj);
		}
	}
}

/**
	The `PluginHook` classes can be used to add hooks to the
	compilation process. That way, users can add their
	own modular modifications to your target.

	Each hook takes a function that receives and returns
	a the specified `DataType` type. The input is the default
	output if the hook didn't exist.

	To add additional parameters to the hook, the `PluginHook1`,
	`PluginHook2`, etc. classes can be used based on the number
	of parameters required.
**/
class PluginHook<DataType> {
	var hooks: Array<(Null<DataType>) -> PluginHookResult<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>) -> PluginHookResult<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>): PluginHookResult<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			switch(h(result)) {
				case null | IgnorePlugin: {
					continue;
				}
				case OutputNothing: {
					return OutputNothing;
				}
				case OverwriteOutput(output): {
					result = output;
				}
			}
		}
		return result;
	}
}

class PluginHook1<DataType, T> {
	var hooks: Array<(Null<DataType>, T) -> PluginHookResult<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T) -> PluginHookResult<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T): PluginHookResult<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			switch(h(result, obj)) {
				case null | IgnorePlugin: {
					continue;
				}
				case OutputNothing: {
					return OutputNothing;
				}
				case OverwriteOutput(output): {
					result = output;
				}
			}
		}
		return result;
	}
}

class PluginHook2<DataType, T, U> {
	var hooks: Array<(Null<DataType>, T, U) -> PluginHookResult<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T, U) -> PluginHookResult<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T, obj2: U): PluginHookResult<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			switch(h(result, obj, obj2)) {
				case null | IgnorePlugin: {
					continue;
				}
				case OutputNothing: {
					return OutputNothing;
				}
				case OverwriteOutput(output): {
					result = output;
				}
			}
		}
		return result;
	}
}

class PluginHook3<DataType, T, U, V> {
	var hooks: Array<(Null<DataType>, T, U, V) -> PluginHookResult<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T, U, V) -> PluginHookResult<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T, obj2: U, obj3: V): PluginHookResult<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			switch(h(result, obj, obj2, obj3)) {
				case null | IgnorePlugin: {
					continue;
				}
				case OutputNothing: {
					return OutputNothing;
				}
				case OverwriteOutput(output): {
					result = output;
				}
			}
		}
		return result;
	}
}

class PluginHook4<DataType, T, U, V, W> {
	var hooks: Array<(Null<DataType>, T, U, V, W) -> PluginHookResult<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T, U, V, W) -> PluginHookResult<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T, obj2: U, obj3: V, obj4: W): PluginHookResult<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			switch(h(result, obj, obj2, obj3, obj4)) {
				case null | IgnorePlugin: {
					continue;
				}
				case OutputNothing: {
					return OutputNothing;
				}
				case OverwriteOutput(output): {
					result = output;
				}
			}
		}
		return result;
	}
}

#end
