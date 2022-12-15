// =======================================================
// * OutputManager
//
// Class containing all code related to generating the
// output files from the compiled classes.
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

import haxe.macro.Context;
import haxe.macro.Type;

import reflaxe.BaseCompiler;

using reflaxe.helpers.ClassTypeHelper;

class OutputManager {
	// -------------------------------------------------------
	// constants
	public final GENERATED_LIST_FILENAME = "_GeneratedFiles.txt";

	// -------------------------------------------------------
	// fields
	public var compiler(default, null): BaseCompiler;
	public var outputDir(default, null): Null<String> = null;

	var outputFiles: Array<String> = [];
	var oldOutputFiles: Null<Array<String>> = null;

	// -------------------------------------------------------
	// getters
	var options(get, never): BaseCompilerOptions;
	function get_options(): BaseCompilerOptions return compiler.options;

	// -------------------------------------------------------
	// new
	public function new(compiler: BaseCompiler) {
		this.compiler = compiler;
	}

	// -------------------------------------------------------
	// joinPaths
	static function joinPaths(path1: String, path2: String): String {
		return haxe.io.Path.join([path1, path2]);
	}

	// -------------------------------------------------------
	// setOutputDir
	public function setOutputDir(outputDir: String) {
		this.outputDir = outputDir;
		checkForOldFiles();
	}

	// -------------------------------------------------------
	// old output file management
	function checkForOldFiles() {
		if(shouldDeleteOldOutput()) {
			oldOutputFiles = generatedFilesList();
		}
	}

	function shouldDeleteOldOutput() {
		return options.fileOutputType != SingleFile && options.deleteOldOutput;
	}

	function generatedFilesList() {
		final path = generatedFilesPath();
		if(sys.FileSystem.exists(path)) {
			return sys.io.File.getContent(path).split("\n").filter(s -> s.length > 0);
		}
		return [];
	}

	function generatedFilesPath() {
		return joinPaths(outputDir, GENERATED_LIST_FILENAME);
	}

	function ensureOutputDirExists() {
		if(!sys.FileSystem.exists(outputDir)) {
			sys.FileSystem.createDirectory(outputDir);
		}
	}

	// -------------------------------------------------------
	// generating files stuff
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

		for(path => content in compiler.extraFiles) {
			saveFile(path, content);
		}

		if(shouldDeleteOldOutput()) {
			deleteOldOutputFiles();
			recordAllOutputFiles();
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
		for(c in compiler.classes) {
			outputs.push(c.output);
		}
		saveFileImpl(filePath, outputs.join("\n\n"));
	}

	function generateFilePerModule() {
		ensureOutputDirExists();

		final files: Map<String, Array<String>> = [];
		for(c in compiler.classes) {
			final mid = c.cls.moduleId();
			if(!files.exists(mid)) {
				files[mid] = [];
			}
			files[mid].push(c.output);
		}

		for(moduleId => outputList in files) {
			final filename = getFileName(moduleId);
			saveFile(filename, outputList.join("\n\n"));
		}
	}

	function generateFilePerClass() {
		ensureOutputDirExists();
		for(c in compiler.classes) {
			saveFile(getFileName(c.cls.globalName()), c.output);
		}
	}

	function getFileName(filename: String): String {
		return filename + options.fileOutputExtension;
	}

	// -------------------------------------------------------
	// saveFile
	public function saveFile(path: String, content: String) {
		final p = outputDir != null ? joinPaths(outputDir, path) : path;
		saveFileImpl(p, content);
	}

	function saveFileImpl(path: String, content: String) {
		sys.io.File.saveContent(path, content);
		if(shouldDeleteOldOutput()) {
			recordOutputFile(path);
		}
	}

	// -------------------------------------------------------
	// record and delete output files
	function recordOutputFile(path: String) {
		final dir = StringTools.endsWith(outputDir, "/") ? outputDir : (outputDir + "/");
		final outputFilePath = StringTools.replace(path, dir, "");
		outputFiles.push(outputFilePath);

		// -------------------------------------------------------
		// We overwrote this file if it existed, so we can
		// remove it from old files we're planning to delete.
		if(oldOutputFiles.contains(outputFilePath)) {
			oldOutputFiles.remove(outputFilePath);
		}
	}

	// -------------------------------------------------------
	// We've removed elements from this array if we saved
	// a new file with the same path, so we can safely assume
	// all the remaining elements are old file paths we
	// want to delete.
	function deleteOldOutputFiles() {
		for(file in oldOutputFiles) {
			final filePath = joinPaths(outputDir, file);
			if(sys.FileSystem.exists(filePath)) {
				try {
					sys.FileSystem.deleteFile(filePath);
				} catch(e) {
					Context.warning('Could not delete file at "$filePath".\n$e', Context.currentPos());
				}
			}
		}
	}

	function recordAllOutputFiles() {
		if(outputFiles.length > 0) {
			sys.io.File.saveContent(generatedFilesPath(), outputFiles.join("\n"));
		}
	}
}

#end
