import XCTest

final class BreweryRemoteLoader {
    init(httpClient: HTTPClientSpy) {

    }
}

final class HTTPClientSpy {
    private(set) var requestedURL: URL?
}

final class BreweryRemoteLoaderTests: XCTestCase {

    func test_init_shouldNotRequestDataFromURL() {
        let httpClient = HTTPClientSpy()
        _ = BreweryRemoteLoader(httpClient: httpClient)
        XCTAssertNil(httpClient.requestedURL)
    }
}
