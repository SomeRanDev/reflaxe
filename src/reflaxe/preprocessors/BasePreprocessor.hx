package reflaxe.preprocessors;

import reflaxe.data.ClassFieldData;

abstract class BasePreprocessor {
	public abstract function process(data: ClassFieldData, compiler: BaseCompiler): Void;
}
