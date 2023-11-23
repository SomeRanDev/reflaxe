// ==================================================================
// * Reflaxe Run.hx
//
// This is the script run when using `haxelib run reflaxe`
//
// It's main feature is generating a new project by copying the contents
// of the "newproject" folder into wherever the user prefers.
// ==================================================================

package;

using StringTools;

import haxe.io.Eof;
import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

/**
	The commands that can be used with this script.
**/
final commands = {
	help: {
		desc: "Shows this message",
		args: [],
		act: (args) -> Sys.println(helpContent()),
		example: "help",
		order: 0
	},
	"new": {
		desc: "Create a new Reflaxe project",
		args: [],
		act: (args: Array<String>) -> createNewProject(args),
		example: "new Rust rs",
		order: 1
	},
	test: {
		desc: "Test your target on .hxml project",
		args: ["hxml_path"],
		act: (args: Array<String>) -> testProject(args),
		example: "test test/Test.hxml",
		order: 2
	},
	build: {
		desc: "Build your project for distribution",
		args: ["build_folder"],
		act: (args: Array<String>) -> buildProject(args),
		example: "build _Build",
		order: 3
	}
}

/**
	The directory this command was run in.
**/
var dir: String = "";

/**
	Main function.
**/
function main() {
	final args = Sys.args();
	dir = args.splice(args.length - 1, 1)[0];
	final mainCommand = args.length < 1 ? "help" : args[0];
	if(Reflect.hasField(commands, mainCommand)) {
		Reflect.callMethod(commands, Reflect.getProperty(commands, mainCommand).act, [args.slice(1)]);
	} else {
		printlnRed("Could not find command: " + mainCommand + "\n");
		commands.help.act(args);
	}
}

/**
	Get path relative to directory this command was run in.
**/
function getPath(p: String) {
	return FileSystem.absolutePath(haxe.io.Path.join([dir, p]));
}

/**
	Make the directory of path `p` if it doesn't exist.
**/
function makeDirIfNonExist(p: String) {
	if(!FileSystem.exists(p)) {
		FileSystem.createDirectory(p);
	}
}

/**
	Print in red or green.
**/
function printlnRed(msg: String) { Sys.println('\033[1;31m${msg}\033[0m'); }
function printlnGreen(msg: String) { Sys.println('\033[1;32m${msg}\033[0m'); }
function printlnGray(msg: String) { Sys.println('\033[1;30m${msg}\033[0m'); }

/**
	Generate the content shown for the help command.
**/
function helpContent(): String {
	var maxFieldSize = -1;

	final commandNames = Reflect.fields(commands);
	commandNames.sort((a, b) -> {
		final i = Reflect.getProperty(commands, a)?.order ?? 9999;
		final j = Reflect.getProperty(commands, b)?.order ?? 9999;
		return i - j;
	});

	// Convert "commands" into an array
	final data = [];
	for(field in commandNames) {
		final c = Reflect.getProperty(commands, field);
		final args = c.args.map(c -> "<" + c + ">").join(" ");
		final helpName = field + (args.length > 0 ? (" " + args) : "");

		if(helpName.length > maxFieldSize) {
			maxFieldSize = helpName.length;
		}
		data.push({ name: field, helpName: helpName, command: c });
	}

	// Load haxelib.json
	final haxelibJson: { version: String, description: String } = haxe.Json.parse(sys.io.File.getContent("./haxelib.json"));

	final picture = "/  ( ˘▽˘)っ♨ \\";
	final title = '/ Reflaxe v${haxelibJson.version} \\';

	// Ensure "credits" is longer than "title"
	var credits = "by SomeRanDev (Robert Borghese)";
	if(title.length > credits.length) {
		final half = Math.floor((title.length - credits.length) / 2);
		credits = StringTools.rpad(StringTools.lpad(credits, " ", half), " " , half);
	}
	credits = "/ " + credits + " \\";

	// Helper
	function space(count: Int, char: String = " ")
		return StringTools.lpad("", char, count);

	final spacing = space(Math.floor((credits.length - title.length) / 2) - 1);
	final pictureSpacing = spacing + space(Math.floor((title.length - picture.length) / 2) - 1);

	final lines = [
		space(5) + pictureSpacing + "/\\/\\/\\/\\/\\",
		space(4) + pictureSpacing + space(picture.length - 1, "="),
		space(3) + pictureSpacing + picture,
		space(3) + spacing + space(title.length - 2, "-"),
		space(2) + spacing + title,
		space(2) + space(credits.length - 2, "-"),
		space(1) + credits,
		space(credits.length + 2, "=")
	];

	// Make help content
	return (
'${lines.join("\n")}

[ ~ Description ~ ]
  ${haxelibJson.description}

[ ~ Commands ~ ]
${
	data
	.map((d) -> "  " + StringTools.rpad(d.helpName, " ", maxFieldSize + 5) + " " + d.command.desc)
	.join("\n")
}
'
	);
}

/**
	Generate the new project.
**/
function createNewProject(args: Array<String>) {
	// Intro message
	printlnGreen("Let's get some info about the target we're generating code for!
Can you tell me...\n");

	// Full Name
	final fullName = args.length >= 1 ? args[0] : readName("Full name? (i.e: Rust, Kotlin, JavaScript)");
	if(fullName == null) return;

	// Ensure folder is available based on Full Name
	final folderName = "reflaxe_" + fullName;
	final folderPath = getPath(folderName);
	if(sys.FileSystem.exists(folderPath)) {
		printlnRed("Unfortunately this name cannot be used since there is already a directory named `" + folderName + "`. Please delete this folder or run this command somewhere else!
\n" + folderPath);
		return;
	}

	// Abbreviated Name
	final abbrevName = args.length >= 2 ? args[1] : readName("Abbreviated name? (i.e: rust, kt, js)");
	if(abbrevName == null) return;
	
	// File Extension
	final extension = args.length >= 3 ? args[2] : readName("File extension for the files to generate?\nDo not include the dot! (i.e: rs, kt, js)");
	if(extension == null) return;

	// Project Type
	final type = args.length >= 4 ? convertStringToProjectType(args[3]) : readProjectType();
	if(type == null) return;

	// ---

	// Verify Info
	Sys.println("---\n");
	Sys.println('Full Name\n  ${fullName}\n
Abbreviated Name\n  ${abbrevName}\n
File Extension\n  .${extension}\n
Transpile Type\n  ${Std.string(type)}');

	final isCorrect = if(args.length < 4) {
		Sys.print("\nIs this OK? (yes)\n>");
		try { Sys.stdin().readLine().toLowerCase(); } catch(e: Eof) { return; }
	} else {
		"";
	}
	
	if(isCorrect == "" || isCorrect == "y" || isCorrect == "yes") {
		Sys.println("");
		printlnGreen("Perfect! Generating project in subfolder: " + folderName);
		copyProjectFiles(folderPath, fullName, abbrevName, extension, type);
	} else {
		printlnRed("\nOkay! Cancelling....");
	}
}

/**
	Read the user input and ensure its valid.

	If canceled using CTRL+C, returns null.
**/
function readName(msg: String): Null<String> {
	final regex = ~/^[a-zA-Z][a-zA-Z0-9_]*$/;

	Sys.println(msg);

	var result = "";
	while(true) {
		Sys.print("> ");
		try {
			result = Sys.stdin().readLine().trim();
		} catch(e: Eof) {
			return null;
		}
		if(regex.match(result)) {
			Sys.println("");
			break;
		} else {
			printlnRed('`${result}` is invalid! It name must only contain alphanumeric characters or underscores. Please try again:');
		}
	}

	return result;
}

/**
	Used as the result for `readProjectType`.
**/
enum ProjectType {
	Direct;
	Intermediate;
}

/**
	Ask the user their desired project type.
**/
function readProjectType(): Null<ProjectType> {
	// Print the message
	Sys.println("What type of compiler would you like to make? (d)irect or (i)ntermediate?
If you're not sure, I recommend using \"direct\"!");

	// Find the result
	final regex = ~/^(?:d|i|direct|intermediate)$/;
	var input = "";
	var result = null;
	while(true) {
		Sys.print("> ");
		try {
			input = Sys.stdin().readLine().trim();
		} catch(e: Eof) {
			return null;
		}
		if(regex.match(input)) {
			result = convertStringToProjectType(input);
			Sys.println("");
			break;
		} else {
			printlnRed('`${input}` is invalid! Please input either \"d\" or \"i\".');
		}
	}

	return result;
}

/**
	Converts a given user-input `String` to its correlating `ProjectType` value.
**/
function convertStringToProjectType(input: String) {
	return switch(input) {
		case "direct" | "d": Direct;
		case "intermediate" | "i": Intermediate;
		case _: {
			printlnRed('`${input}` is an invalid project type.');
			null;
		}
	}
}

/**
	Actually copies the project files.
**/
function copyProjectFiles(folderPath: String, fullName: String, abbrName: String, ext: String, type: ProjectType) {
	if(!FileSystem.exists("newproject")) {
		printlnRed("Could not find `newproject` directory in Reflaxe installation folder.");
		return;
	}

	copyDir("newproject", folderPath, { fullName: fullName, abbrName: abbrName, ext: ext, type: type });
}

/**
	Recursive function for copying files.
	Handles special cases.
**/
function copyDir(src: String, dest: String, data: { fullName: String, abbrName: String, ext: String, type: ProjectType }) {
	// Check if directory is exclusive to a project type.
	final dirRegex = ~/\.(direct|intermediate)$/i;
	if(dirRegex.match(src)) {
		if(dirRegex.matched(1).toLowerCase() != Std.string(data.type).toLowerCase()) {
			return;
		} else {
			// Remove the .direct|intermediate from the destination.
			dest = dirRegex.replace(dest, "");
		}
	}

	// Make directory
	makeDirIfNonExist(dest);

	// Copy files
	for(file in FileSystem.readDirectory(src)) {
		final filePath = Path.join([src, file]);
		var destFile = Path.join([dest, file]);
		if(FileSystem.isDirectory(filePath)) {
			switch(file) {
				// rename src/langcompiler
				case "langcompiler":
					destFile = Path.join([dest, data.abbrName.toLowerCase() + "compiler"]);
				case "LANG":
					destFile = Path.join([dest, data.abbrName.toLowerCase()]);
				// ignore test/out and _Build
				case "out" | "_Build":
					continue;
				case _:
			}
			copyDir(filePath, destFile, data);
		} else {
			final content = File.getContent(filePath);
			File.saveContent(destFile, replaceFileContent(content, data));
		}
	}
}

/**
	Replaces content from the "newproject/" files
	to match with the user config.
**/
function replaceFileContent(content: String, data: { fullName: String, abbrName: String, ext: String }): String {
	final lowerAbbrName = data.abbrName.toLowerCase();
	return content.replace("langcompiler", lowerAbbrName + "compiler")
		.replace("package lang", "package " + lowerAbbrName)
		.replace("__lang__", "__" + lowerAbbrName + "__")
		.replace("lang-output", lowerAbbrName + "-output")
		.replace("LANGUAGE", data.fullName)
		.replace("LANG", data.abbrName)
		.replace("EXTENSION", data.ext);
}

/**
	Checks if the directory the command was ran in is a Reflaxe project.

	If it is, a JSON object of the haxelib.json is returned.
	Otherwise, `null` is returned.
**/
function ensureIsReflaxeProject(): Null<Dynamic> {
	var haxelibJson: Dynamic = null;
	final haxelibJsonPath = Path.join([dir, "haxelib.json"]);
	if(!FileSystem.exists(haxelibJsonPath)) {
		printlnRed("haxelib.json file not found!\nThis command must be run in a Reflaxe project.");
	} else {
		final haxelibJsonContent = File.getContent(haxelibJsonPath);
		haxelibJson = haxe.Json.parse(haxelibJsonContent);
		if(haxelibJson.reflaxe == null) {
			printlnRed("haxelib.json expected to contain Reflaxe project information.");
			printlnRed("Please add the following to your haxelib.json to use this command:");
			Sys.println('"reflaxe": {
    "name": "<Your Language Name>",
    "abbr": "<Your Abbreviated Language Name>",
    "stdPaths": []
}');
			return null;
		}
		return haxelibJson;
	}

	return null;
}

/**
	The function for running the `test` command.
**/
function testProject(args: Array<String>) {
	final path = if(args.length == 0) {
		Sys.println("No .hxml path provided, using test/Test.hxml\n");
		"test/Test.hxml";
	} else if(args.length == 1) {
		args[0];
	} else {
		printlnRed("Too many arguments provided.");
		return;
	}

	final haxelibJson = ensureIsReflaxeProject();
	if(haxelibJson == null) return;

	// Validate the path
	if(!FileSystem.exists(path)) {
		return printlnRed("`" + path + "` does not exist!");
	} else if(Path.extension(path) != "hxml") {
		return printlnRed("`" + path + "` must be a .hxml file!");
	}

	// Get current cwd
	// Remember, the command directory is stored in "dir", not "Sys.getCwd()"!!
	var cwd = dir;
	final hxmlDir = Path.directory(path);

	// Convert cwd to relative path if possible
	if(!Path.isAbsolute(hxmlDir)) {
		final folders = ~/\/\\/g.split(hxmlDir);
		cwd = Path.join(folders.map(f -> ".."));
	}

	// Change cwd
	Sys.setCwd(Path.join([dir, hxmlDir]));
	printlnGray("cd " + hxmlDir);

	// Generate arguments
	final getProjPath = (p: ...String) -> Path.normalize(Path.join([cwd].concat(p.toArray())));
	final haxeArgs = [
		Path.withoutDirectory(path),
		"-lib reflaxe",
		"-D reflaxe_measure",
		getProjPath("extraParams.hxml"),
		"-p " + getProjPath(haxelibJson.classPath)
	];
	for(stdPath in (haxelibJson.reflaxe?.stdPaths ?? [])) {
		haxeArgs.push("-p " + getProjPath(stdPath));
	}

	// Run Haxe project
	printlnGray("haxe " + haxeArgs.join(" "));
	final exitCode = Sys.command("haxe", haxeArgs.join(" ").split(" "));

	// Print exit code
	final msg = "Haxe compiler returned exit code " + exitCode;
	if(exitCode == 0) printlnGreen(msg);
	else printlnRed(msg);
}

/**
	The function for running the `build` command.
**/
function buildProject(args: Array<String>) {
	// Validate project, get haxelib.json
	final haxelibJson = ensureIsReflaxeProject();
	if(haxelibJson == null) return;

	// Get destination folder
	final destFolder = if(args.length == 0) {
		Sys.println("No build folder path provided, using _Build/\n");
		"_Build";
	} else if(args.length == 1) {
		args[0];
	} else  {
		printlnRed("Too many argument provided.");
		return;
	}

	// Ensure destination folder name valid
	if(!~/^[A-Za-z0-9_]+$/.match(destFolder)) {
		printlnRed("`" + destFolder + "` is not a valid folder name!\nPlease only use alphanumeric characters and underscores!");
		return;
	}

	// Ensure destination folder relative to cwd
	final destFolder = Path.join([dir, destFolder]);

	// Check if destination folder already exists
	if(FileSystem.exists(destFolder)) {
		if(!FileSystem.isDirectory(destFolder)) {
			printlnRed("There is already a file named `" + destFolder + "`.\nPlease input a different path for the build folder.");
			return;
		} else {
			// If a folder already exists, ask to delete
			Sys.println("There is already a folder named `" + destFolder + "`.\nWould you like to delete it? (yes/no)");
			Sys.print("> ");
			final response = try { Sys.stdin().readLine().toLowerCase(); } catch(e: Eof) { return; }
			if(response == "yes" || response == "y") {
				Sys.println("Deleting...\n");
				deleteDir(destFolder);
			} else {
				Sys.println("Okay! Cancelling build!");
				return;
			}
		}
	}

	// Make destination folder
	makeDirIfNonExist(destFolder);

	// Copy source files if possible
	final classPath = haxelibJson.classPath;
	if(classPath.length != null && classPath.length > 0) {
		// Copy class path
		final dirNormalized = Path.addTrailingSlash(Path.normalize(dir));
		final classPathSrc = Path.join([dir, classPath]);
		final classPathDest = Path.join([destFolder, classPath]);
		copyDirContent(classPathSrc, classPathDest, dirNormalized);
		Sys.println("Copying class path: " + Path.addTrailingSlash(classPath));

		// Copy std paths
		final stdPaths: Array<String> = cast (haxelibJson.reflaxe?.stdPaths ?? []);
		for(stdPath in stdPaths) {
			final stdPathSrc = Path.join([dir, stdPath]);
			final ext = StringTools.endsWith(Path.removeTrailingSlashes(stdPath), "_std") ? ".cross.hx" : null;
			copyDirContent(stdPathSrc, classPathDest, dirNormalized, stdPaths, ext);
			Sys.println("Copying std path: " + Path.addTrailingSlash(stdPath));
		}

		// Copy extra files
		function copyExtraFile(file: String, printError: Bool) {
			final filePath = Path.join([dir, file]);
			if(FileSystem.exists(filePath)) {
				File.copy(filePath, Path.join([destFolder, file]));
				Sys.println("Copying file: " + file);
			} else if(printError) {
				printlnRed("Could not find file: " + file + "; ignoring...");
			}
		}

		// Files that should exist
		for(file in ["haxelib.json", "LICENSE", "README.md"]) {
			copyExtraFile(file, true);
		}

		// Files that are okay to not exist
		for(file in ["extraParams.hxml", "Run.hx", "run.n"]) {
			copyExtraFile(file, false);
		}

		// Print success
		Sys.println("");
		printlnGreen("Build successful:\n" + destFolder);
	} else {
		// Print failure
		printlnRed("\"classPath\" must be defined in haxelib.json to build the project.");
	}
}

/**
	Util function for recursively copying directories containing source files.

	`ignore` is a list of directories that should not be copied.
	`replaceExt` replaces the extension for all copied source files if provided.
**/
function copyDirContent(from: String, to: String, basePath: String, ignore: Null<Array<String>> = null, replaceExt: Null<String> = null) {
	if(FileSystem.exists(from)) {
		for(file in FileSystem.readDirectory(from)) {
			final path = Path.join([from, file]);
			var dest = Path.join([to, file]);
			if(!FileSystem.isDirectory(path)) {
				if(replaceExt != null) {
					dest = Path.withoutExtension(dest) + replaceExt;
				}
				File.copy(path, dest);
			} else {
				if(ignore != null && ignore.contains(Path.removeTrailingSlashes(path.replace(basePath, "")))) {
					continue;
				}
				final d = Path.addTrailingSlash(path);
				final d2 = Path.addTrailingSlash(dest);
				makeDirIfNonExist(d2);
				copyDirContent(d, d2, basePath, ignore, replaceExt);
			}
		}
	}
}

/**
	Deletes directory even if it has content within it.

	Based on:
		https://ashes999.github.io/learnhaxe/recursively-delete-a-directory-in-haxe.html
**/
function deleteDir(path: String) {
	if(FileSystem.exists(path) && FileSystem.isDirectory(path)) {
		final entries = FileSystem.readDirectory(path);
		for(entry in entries) {
			if (FileSystem.isDirectory(path + "/" + entry)) {
				deleteDir(path + "/" + entry);
				FileSystem.deleteDirectory(path + "/" + entry);
			} else {
				FileSystem.deleteFile(path + "/" + entry);
			}
		}
	}
}
