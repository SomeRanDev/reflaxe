package reflaxe.preprocessors;

import reflaxe.data.ClassFuncData;

abstract class BasePreprocessor {
	public abstract function process(data: ClassFuncData, compiler: BaseCompiler): Void;
}
