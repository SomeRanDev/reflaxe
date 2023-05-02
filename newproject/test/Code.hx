// A bit of code to compile with your custom compiler.
//
// This code has no relevance beyond testing purposes.
// Please modify and add your own test code!

package;

enum TestEnum {
	One;
	Two;
	Three;
}

class TestClass {
	var field: TestEnum;

	public function new() {
		trace("Create Code class!");
		field = One;
	}

	public function increment() {
		switch(field) {
			case One: field = Two;
			case Two: field = Three;
			case _:
		}
		trace(field);
	}
}

function main() {
	trace("Hello world!");

	final c = new TestClass();
	for(i in 0...3) {
		c.increment();
	}
}
