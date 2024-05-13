import Foundation
import UIKit

// workaround for MoltenVK problem that causes flicker
// https://github.com/mpv-player/mpv/pull/13651
class MetalLayer: CAMetalLayer {
    // workaround for a MoltenVK workaround that sets the drawableSize to 1x1 to forcefully complete
    // the presentation, this causes flicker and the drawableSize possibly staying at 1x1
    override var drawableSize: CGSize {
        get { return super.drawableSize }
        set {
            if Int(newValue.width) > 1 && Int(newValue.height) > 1 {
                super.drawableSize = newValue
            }
        }
    }
}
