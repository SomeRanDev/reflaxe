package reflaxe.debug;

#if (macro || reflaxe_runtime)

#if eval
import eval.integers.UInt64;
import eval.luv.Time;
#end

using StringTools;

/**
	Measures time during eval/macro.

	```haxe
	// Create when you want to start measuring.
	final m = new MeasurePerformance();

	//! DO SOMETHING THAT TAKES A WHILE

	// Measure and print the time.
	// %NANO% and %SECONDS% can also be used.
	m.measure("That took %MILLI% milliseconds");

	// Alternatively, get the time value directly as `UInt64`.
	final time: eval.integers.UInt64 = m.timeSinceCreated();
	```
**/
abstract MeasurePerformance(#if eval UInt64 #else Int #end) {
	public inline function new() {
		#if eval
		this = Time.hrTime();
		#else
		this = 0;
		#end
	}

	public inline function timeSinceCreated(): #if eval UInt64 #else Int #end {
		#if eval
		return Time.hrTime() - this;
		#else
		return 0;
		#end
	}

	public inline function millisecondsString(): String {
		#if eval
		return formatNumber(timeSinceCreated(), 6);
		#else
		return "0";
		#end
	}

	public inline function secondsString(): String {
		#if eval
		return formatNumber(timeSinceCreated(), 9);
		#else
		return "0";
		#end
	}

	public function measure(formatString: Null<String> = null, posInfos: Null<haxe.PosInfos> = null) {
		#if eval
		final nanoseconds = timeSinceCreated();

		if(formatString != null) {
			final formatted = ~/(?:%NANO%|%MILLI%|%SECONDS%)/g.map(formatString, function(regex) {
				return switch(regex.matched(0)) {
					case "%MILLI%": millisecondsString();
					case "%SECONDS%": secondsString();
					case _: nanoseconds.toString();
				}
			});

			Sys.println(formatted);
		} else {
			final milliseconds = formatNumber(nanoseconds, 6);
			haxe.Log.trace(milliseconds + " milliseconds.", posInfos);
		}
		#end
	}

	#if eval
	function formatNumber(value: UInt64, decimalOffset: Int) {
		final nanosecondsString = StringTools.lpad(value.toString(), "0", decimalOffset + 1);
		return nanosecondsString.substr(0, nanosecondsString.length - decimalOffset) + "." + nanosecondsString.substr(-decimalOffset);
	}
	#end
}

#end
