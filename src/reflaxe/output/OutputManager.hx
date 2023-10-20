// =======================================================
// * OutputManager
// =======================================================

package reflaxe.output;

#if (macro || reflaxe_runtime)

import haxe.io.BytesBuffer;
import haxe.macro.Context;

import reflaxe.BaseCompiler;

// ---

using Lambda;

using reflaxe.helpers.BaseTypeHelper;
using reflaxe.helpers.NullHelper;

/**
	Class containing all code related to generating the
	output files from the compiled classes.
**/
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
		return joinPaths(outputDir.or(""), GENERATED_LIST_FILENAME);
	}

	function ensureOutputDirExists() {
		if(outputDir != null && !sys.FileSystem.exists(outputDir)) {
			sys.FileSystem.createDirectory(outputDir);
		}
	}

	/**
		Generates the output files.
	**/
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
			final keys = [];
			for(priority => cpp in content) {
				if(StringTools.trim(cpp).length > 0) {
					keys.push(priority);
				}
			}

			keys.sort((a, b) -> a - b);

			var result = [];
			for(k in keys) {
				final c = content.get(k);
				if(c != null && StringTools.trim(c).length > 0) {
					result.push(c);
				}
			}

			saveFile(path, result.join("\n\n"));
		}

		if(shouldDeleteOldOutput()) {
			deleteOldOutputFiles();
			recordAllOutputFiles();
		}
	}

	function generateSingleFile() {
		if(outputDir == null) {
			throw "Output directory is not defined.";
			return;
		}

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

		final arr = [];
		for(o in compiler.generateOutputIterator()) arr.push(o.data);
		saveFileImpl(filePath, joinStringOrBytes(arr));
	}

	function generateFilePerModule() {
		ensureOutputDirExists();

		final files: Map<String, Array<StringOrBytes>> = [];
		for(c in compiler.generateOutputIterator()) {
			final mid = c.baseType.moduleId();
			final filename = overrideFileName(mid, c);
			if(!files.exists(filename)) {
				files[filename] = [];
			}
			final f = files[filename];
			if(f != null) {
				f.push(c.data);
			}
		}

		for(moduleId => outputList in files) {
			final filename = getFileName(moduleId);
			saveFileImpl(filename, joinStringOrBytes(outputList));
		}
	}

	static function joinStringOrBytes(list: Array<StringOrBytes>): StringOrBytes {
		final strings = [];
		final bytes = [];
		for(o in list) {
			switch(o.data()) {
				case String(s): strings.push(s);
				case Bytes(b): bytes.push(b);
			}
		}

		if(strings.length > 0 && bytes.length > 0) {
			throw "Cannot mix String and Bytes outputs for join.";
		}

		return if(strings.length > 0) {
			strings.join("\n\n");
		} else if(bytes.length > 0) {
			final bb = new BytesBuffer();
			for(b in bytes) bb.add(b);
			bb.getBytes();
		} else {
			"";
		}
	}

	function generateFilePerClass() {
		ensureOutputDirExists();
		for(c in compiler.generateOutputIterator()) {
			final filename = overrideFileName(c.baseType.globalName(), c);
			saveFile(getFileName(filename), c.data);
		}
	}

	inline function overrideFileName(defaultName: String, o: {
		var overrideFileName(default, null): Null<String>;
		var overrideDirectory(default, null): Null<String>;
	}) {
		return (o.overrideDirectory != null ? o.overrideDirectory + "/" : "") + (o.overrideFileName ?? defaultName);
	}

	function getFileName(filename: String): String {
		return filename + options.fileOutputExtension;
	}

	/**
		Internal helper function for saving content to a path
		relative to the output folder.
	**/
	public function saveFile(path: String, content: StringOrBytes) {
		// Get full path
		final p = outputDir != null ? joinPaths(outputDir, path) : path;

		// Ensure directories exist
		final dir = haxe.io.Path.directory(p);
		if(!sys.FileSystem.exists(dir)) {
			sys.FileSystem.createDirectory(dir);
		}

		// Save file
		saveFileImpl(p, content);
	}

	function saveFileImpl(path: String, content: StringOrBytes) {
		// Do not save anything if the file already exists and has same content
		if(!sys.FileSystem.exists(path) || !content.matchesFile(path)) {
			content.save(path);
		}
		if(shouldDeleteOldOutput()) {
			recordOutputFile(path);
		}
	}

	/**
		Records a path for a file that was generated.
		Ensures it will not be deleted when the rest of the old source files are removed.
	**/
	function recordOutputFile(path: String) {
		if(outputDir == null) return;
		final dir = StringTools.endsWith(outputDir, "/") ? outputDir : (outputDir + "/");
		final outputFilePath = StringTools.replace(path, dir, "");
		outputFiles.push(outputFilePath);

		// -------------------------------------------------------
		// We overwrote this file if it existed, so we can
		// remove it from old files we're planning to delete.
		if(oldOutputFiles != null && oldOutputFiles.contains(outputFilePath)) {
			oldOutputFiles.remove(outputFilePath);
		}
	}

	/**
		We've removed elements from this array if we saved
		a new file with the same path, so we can safely assume
		all the remaining elements are old file paths we
		want to delete.
	**/
	function deleteOldOutputFiles() {
		if(oldOutputFiles != null && outputDir != null) {
			for(file in oldOutputFiles) {
				final filePath = joinPaths(outputDir, file);
				if(sys.FileSystem.exists(filePath)) {
					try {
						sys.FileSystem.deleteFile(filePath);
					} catch(e) {
						#if eval
						Context.warning('Could not delete file at "$filePath".\n$e', Context.currentPos());
						#end
					}
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
