package langcompiler;

#if (macro || LANG_runtime)

import reflaxe.ReflectCompiler;

class CompilerInit {
	public static function Start() {
		#if !eval
		Sys.println("CompilerInit.Start can only be called from a macro context.");
		return;
		#end

		#if (haxe_ver < "4.3.0")
		Sys.println("Reflaxe/LANGUAGE requires Haxe version 4.3.0 or greater.");
		return;
		#end

		ReflectCompiler.AddCompiler(new Compiler(), {
			fileOutputExtension: ".EXTENSION",
			outputDirDefineName: "LANG-output",
			fileOutputType: FilePerClass,
			reservedVarNames: reservedNames(),
			targetCodeInjectionName: "__LANG__",
			smartDCE: true,
			trackUsedTypes: true
		});
	}

	static function reservedNames() {
		return [];
	}
}

#end
