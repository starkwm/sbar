import Foundation
import Testing
@testable import StarkBar

@Suite("Foundation geometry")
struct FoundationTests {
    @Test("Placement respects usable display bounds and negative origins")
    func placement() {
        let visible = CGRect(x: -1440, y: 40, width: 1440, height: 836)
        #expect(BarPlacement.frame(in: visible, settings: .init(position: .top)) == CGRect(x: -1440, y: 844, width: 1440, height: 32))
        #expect(BarPlacement.frame(in: visible, settings: .init(position: .bottom)) == CGRect(x: -1440, y: 40, width: 1440, height: 32))
    }

    @Test("Bar height cannot exceed available display height")
    func smallDisplay() {
        let visible = CGRect(x: 0, y: 0, width: 100, height: 24)
        #expect(BarPlacement.frame(in: visible, settings: .init()) == visible)
    }

    @Test("Wide center content leaves equal nonoverlapping side regions")
    func wideCenter() {
        #expect(BarRegionLayout.widths(available: 300, centerIdeal: 500) == [90, 100, 90])
    }

    @Test("Empty center releases its budget to the sides")
    func emptyCenter() {
        #expect(BarRegionLayout.widths(available: 300, centerIdeal: 0) == [150, 0, 150])
    }

    @Test("Narrow layouts never produce negative widths", arguments: [0.0, 1.0, 10.0, 20.0])
    func narrowLayout(width: Double) {
        let widths = BarRegionLayout.widths(available: width, centerIdeal: 100)
        #expect(widths.allSatisfy { $0 >= 0 })
        #expect(widths.reduce(0, +) <= width)
        #expect(widths[0] == widths[2])
    }
}
