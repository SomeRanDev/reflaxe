// =======================================================
// * PluginHook
//
// These classes can be used to add hooks to the
// compilation process. That way, users can add their
// own modular modifications to your target.
//
// Each hook takes a function that receives and returns
// a String. To add additional parameters to the hook,
// the generic PluginHook1, PluginHook2, etc. classes
// can be used based on the number of parameters required.
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

class PluginHook {
	var hooks: Array<(Null<String>) -> Null<String>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<String>) -> Null<String>) {
		hooks.push(func);
	}

	public function call(code: Null<String>): Null<String> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result);
		}
		return result;
	}
}

class PluginHook1<T> {
	var hooks: Array<(Null<String>, T) -> Null<String>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<String>, T) -> Null<String>) {
		hooks.push(func);
	}

	public function call(code: Null<String>, obj: T): Null<String> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj);
		}
		return result;
	}
}

class PluginHook2<T, U> {
	var hooks: Array<(Null<String>, T, U) -> Null<String>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<String>, T, U) -> Null<String>) {
		hooks.push(func);
	}

	public function call(code: Null<String>, obj: T, obj2: U): Null<String> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj, obj2);
		}
		return result;
	}
}

class PluginHook3<T, U, V> {
	var hooks: Array<(Null<String>, T, U, V) -> Null<String>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<String>, T, U, V) -> Null<String>) {
		hooks.push(func);
	}

	public function call(code: Null<String>, obj: T, obj2: U, obj3: V): Null<String> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj, obj2, obj3);
		}
		return result;
	}
}

class PluginHook4<T, U, V, W> {
	var hooks: Array<(Null<String>, T, U, V, W) -> Null<String>>;

	public function new() {
		hooks = [];
	}

	public function addHook(func: (Null<String>, T, U, V, W) -> Null<String>) {
		hooks.push(func);
	}

	public function call(code: Null<String>, obj: T, obj2: U, obj3: V, obj4: W): Null<String> {
		if(hooks.length == 0) return code;
		var result = code;
		for(h in hooks) {
			result = h(result, obj, obj2, obj3, obj4);
		}
		return result;
	}
}

#end
