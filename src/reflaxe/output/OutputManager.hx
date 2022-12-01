// =======================================================
// * OutputManager
//
// Class containing all code related to generating the
// output files from the compiled classes.
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

import haxe.macro.Type;

import reflaxe.BaseCompiler;

using reflaxe.helpers.ClassTypeHelper;

class OutputManager {
	public var compiler(default, null): BaseCompiler;
	public var outputDir(default, null): Null<String> = null;

	var options(get, never): BaseCompilerOptions;
	function get_options(): BaseCompilerOptions return compiler.options;

	var classes(get, never): Array<{ cls: ClassType, output: String }>;
	function get_classes(): Array<{ cls: ClassType, output: String }> return compiler.classes;

	public function new(compiler: BaseCompiler) {
		this.compiler = compiler;
	}

	public function setOutputDir(outputDir: String) {
		this.outputDir = outputDir;
	}

	function ensureOutputDirExists() {
		if(!sys.FileSystem.exists(outputDir)) {
			sys.FileSystem.createDirectory(outputDir);
		}
	}

	public function generateFiles() {
		switch(options.fileOutputType) {
			case Manual: {
				compiler.generateFilesManually();
			}
			case SingleFile: {
				generateSingleFile();
			}
			case FilePerModule: {
				generateFilePerModule();
			}
			case FilePerClass: {
				generateFilePerClass();
			}
		}
	}

	function generateSingleFile() {
		final filePath = if(sys.FileSystem.isDirectory(outputDir)) {
			ensureOutputDirExists();
			joinPaths(outputDir, getFileName(options.defaultOutputFilename));
		} else {
			final dir = haxe.io.Path.directory(outputDir);
			if(!sys.FileSystem.exists(dir)) {
				sys.FileSystem.createDirectory(dir);
			}
			outputDir;
		}
		final outputs = [];
		for(c in classes) {
			outputs.push(c.output);
		}
		saveFile(filePath, outputs.join("\n\n"));
	}

	function generateFilePerModule() {
		ensureOutputDirExists();

		final files: Map<String, Array<String>> = [];
		for(c in classes) {
			final mid = c.cls.moduleId();
			if(!files.exists(mid)) {
				files[mid] = [];
			}
			files[mid].push(c.output);
		}

		for(moduleId => outputList in files) {
			final filename = getFileName(moduleId);
			saveFile(joinPaths(outputDir, filename), outputList.join("\n\n"));
		}
	}

	function generateFilePerClass() {
		ensureOutputDirExists();
		for(c in classes) {
			saveFile(joinPaths(outputDir, getFileName(c.cls.globalName())), c.output);
		}
	}

	function getFileName(filename: String): String {
		return filename + options.fileOutputExtension;
	}

	function joinPaths(path1: String, path2: String): String {
		return haxe.io.Path.join([path1, path2]);
	}

	function saveFile(dir: String, content: String) {
		sys.io.File.saveContent(dir, content);
	}
}

#end
