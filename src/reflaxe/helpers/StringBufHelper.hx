package reflaxe.helpers;

class StringBufHelper {
	public static inline extern function addMulti(self: StringBuf, ...args: String) {
		for(a in args) {
			self.add(a);
		}
	}
}
