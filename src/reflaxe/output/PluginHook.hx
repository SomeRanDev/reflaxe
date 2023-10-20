// =======================================================
// * PluginHook
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

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
	var hooks: Array<(Null<DataType>) -> Null<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>) -> Null<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>): Null<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result);
		}
		return result;
	}
}

class PluginHook1<DataType, T> {
	var hooks: Array<(Null<DataType>, T) -> Null<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T) -> Null<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T): Null<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj);
		}
		return result;
	}
}

class PluginHook2<DataType, T, U> {
	var hooks: Array<(Null<DataType>, T, U) -> Null<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T, U) -> Null<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T, obj2: U): Null<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj, obj2);
		}
		return result;
	}
}

class PluginHook3<DataType, T, U, V> {
	var hooks: Array<(Null<DataType>, T, U, V) -> Null<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T, U, V) -> Null<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T, obj2: U, obj3: V): Null<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj, obj2, obj3);
		}
		return result;
	}
}

class PluginHook4<DataType, T, U, V, W> {
	var hooks: Array<(Null<DataType>, T, U, V, W) -> Null<DataType>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<DataType>, T, U, V, W) -> Null<DataType>) {
		hooks.push(func);
	}

	public function call(code: Null<DataType>, obj: T, obj2: U, obj3: V, obj4: W): Null<DataType> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj, obj2, obj3, obj4);
		}
		return result;
	}
}

#end
