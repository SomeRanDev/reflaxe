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
		example: "help"
	},
	"new": {
		desc: "Create a new Reflaxe project",
		args: [],
		act: (args) -> createNewProject(args),
		example: "new Rust rs"
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
		Reflect.callMethod(commands, Reflect.getProperty(commands, mainCommand).act, []);
	} else {
		Sys.println("Could not find command: " + mainCommand + "\n");
		commands.help.act(args.length > 1 ? args.slice(1) : []);
	}
}

/**
	Get path relative to directory this command was run in.
**/
function getPath(p: String) {
	return FileSystem.absolutePath(haxe.io.Path.join([dir, p]));
}

/**
	Print in red or green.
**/
function printlnRed(msg: String) { Sys.println('\033[1;31m${msg}\033[0m'); }
function printlnGreen(msg: String) { Sys.println('\033[1;32m${msg}\033[0m'); }

/**
	Generate the content shown for the help command.
**/
function helpContent(): String {
	var maxFieldSize = -1;

	final commandNames = Reflect.fields(commands);
	commandNames.sort((a, b) -> {
		if(a == "help") return -1;
		else if(b == "help") return 1;
		return a < b ? -1 : 1;
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
	var credits = "by RoBBoR (Robert Borghese)";
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
	final fullName = readName("Full name? (i.e: Rust, Kotlin, JavaScript)");
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
	final abbrevName = readName("Abbreviated name? (i.e: rust, kt, js)");
	if(abbrevName == null) return;
	
	// File Extension
	final extension = readName("File extension for the files to generate?\nDo not include the dot! (i.e: rs, kt, js)");
	if(extension == null) return;

	// ---

	// Verify Info
	Sys.println("---\n");
	Sys.println('Full Name\n  ${fullName}\n
Abbreviated Name\n  ${abbrevName}\n
File Extension\n  .${extension}');
	Sys.print("\nIs this OK? (yes)\n>");
	final isCorrect = try { Sys.stdin().readLine().toLowerCase(); } catch(e: Eof) { return; }
	if(isCorrect == "" || isCorrect == "y" || isCorrect == "yes") {
		Sys.println("");
		printlnGreen("Perfect! Generating project in subfolder: " + folderName);
		copyProjectFiles(folderPath, fullName, abbrevName, extension);
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
	Actually copies the project files.
**/
function copyProjectFiles(folderPath: String, fullName: String, abbrName: String, ext: String) {
	if(!FileSystem.exists("newproject")) {
		printlnRed("Could not find `newproject` directory in Reflaxe installation folder.");
		return;
	}

	copyDir("newproject", folderPath, { fullName: fullName, abbrName: abbrName, ext: ext });
}

/**
	Recursive function for copying files.
	Handles special cases.
**/
function copyDir(src: String, dest: String, data: { fullName: String, abbrName: String, ext: String }) {
	if(!FileSystem.exists(dest)) {
		FileSystem.createDirectory(dest);
	}
	for(file in FileSystem.readDirectory(src)) {
		final filePath = Path.join([src, file]);
		var destFile = Path.join([dest, file]);
		if(FileSystem.isDirectory(filePath)) {
			switch(file) {
				// rename src/langcompiler
				case "langcompiler":
					destFile = Path.join([dest, data.abbrName.toLowerCase() + "compiler"]);
				// ignore test/out
				case "out":
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
		.replace("__lang__", "__" + lowerAbbrName + "__")
		.replace("lang-output", lowerAbbrName + "-output")
		.replace("LANGUAGE", data.fullName)
		.replace("LANG", data.abbrName)
		.replace("EXTENSION", data.ext);
}
