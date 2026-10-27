import Foundation
import Testing

@testable import Cadence

struct FoundationConfigurationTests {
  @Test
  func appBundleIdentifierIsStable() {
    #expect(Bundle.main.bundleIdentifier == "com.kirkgartside.cadence")
  }
}
