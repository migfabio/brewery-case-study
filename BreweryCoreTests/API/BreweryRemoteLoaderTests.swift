import XCTest

final class BreweryRemoteLoader {
    private let httpClient: HTTPClientSpy
    private let url: URL

    init(httpClient: HTTPClientSpy, url: URL) {
        self.httpClient = httpClient
        self.url = url
    }

    func load() {
        httpClient.get(from: url)
    }
}

final class HTTPClientSpy {
    private(set) var requestedURL: URL?

    func get(from url: URL) {
        self.requestedURL = url
    }
}

final class BreweryRemoteLoaderTests: XCTestCase {

    func test_init_shouldNotRequestDataFromURL() {
        let httpClient = HTTPClientSpy()
        _ = BreweryRemoteLoader(httpClient: httpClient, url: URL(string: "https://random.com")!)
        XCTAssertNil(httpClient.requestedURL)
    }

    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://any-url.com")!
        let httpClient = HTTPClientSpy()
        let sut = BreweryRemoteLoader(httpClient: httpClient, url: url)

        sut.load()

        XCTAssertEqual(httpClient.requestedURL, url)
    }
}
