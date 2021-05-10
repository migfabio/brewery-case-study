import XCTest

protocol HTTPClient {
    func get(from url: URL)
}

final class BreweryRemoteLoader {
    private let httpClient: HTTPClient
    private let url: URL

    init(httpClient: HTTPClient, url: URL) {
        self.httpClient = httpClient
        self.url = url
    }

    func load() {
        httpClient.get(from: url)
    }
}

final class HTTPClientSpy: HTTPClient {
    private(set) var requestedURL: URL?

    func get(from url: URL) {
        self.requestedURL = url
    }
}

final class BreweryRemoteLoaderTests: XCTestCase {

    func test_init_shouldNotRequestDataFromURL() {
        let (_, httpClient) = makeSUT()
        XCTAssertNil(httpClient.requestedURL)
    }

    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://any-url.com")!
        let (sut, httpClient) = makeSUT(url: url)

        sut.load()

        XCTAssertEqual(httpClient.requestedURL, url)
    }

    private func makeSUT(url: URL = URL(string: "https://given-url.com")!) -> (sut: BreweryRemoteLoader, httpClient: HTTPClientSpy) {
        let httpClient = HTTPClientSpy()
        let sut = BreweryRemoteLoader(httpClient: httpClient, url: url)
        return (sut, httpClient)
    }
}
