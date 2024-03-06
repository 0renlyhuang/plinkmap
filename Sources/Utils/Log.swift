import Foundation

var isDebuging = true
//
func debugLog(_ msg: String) {
    if (isDebuging) {
        print(msg)
    }
}
