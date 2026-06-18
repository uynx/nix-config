import Foundation
import ApplicationServices

let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
guard handle != nil else {
    exit(1)
}

typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
if let sym = dlsym(handle, "DisplayServicesGetLinearBrightness") {
    let f = unsafeBitCast(sym, to: GetBrightness.self)
    var b: Float = 0.0
    if f(CGMainDisplayID(), &b) == 0 {
        print(Int(round(b * 100)))
        exit(0)
    }
}
exit(1)
