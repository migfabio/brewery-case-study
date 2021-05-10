import XCTest

protocol HTTPClient {
    func get(from url: URL, completion: @escaping (Result<Void, Error>) -> Void)
}

final class BreweryRemoteLoader {
    private let httpClient: HTTPClient
    private let url: URL

    enum Error: Swift.Error, Equatable {
        case clientError
    }

    init(httpClient: HTTPClient, url: URL) {
        self.httpClient = httpClient
        self.url = url
    }

    func load(completion: @escaping (Result<Void, Error>) -> Void) {
        httpClient.get(from: url) { _ in
            completion(.failure(.clientError))
        }
    }
}

final class HTTPClientSpy: HTTPClient {
    private var requests = [(url: URL, completion: (Result<Void, Error>) -> Void)]()

    var requestedURLs: [URL] {
        requests.map { $0.url }
    }
    
    func get(from url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        self.requests.append((url, completion))
    }

    func completeWithError(at index: Int) {
        requests[index].completion(.failure(NSError(domain: "", code: 0)))
    }
}

final class BreweryRemoteLoaderTests: XCTestCase {

    func test_init_shouldNotRequestDataFromURL() {
        let (_, httpClient) = makeSUT()
        XCTAssertEqual(httpClient.requestedURLs, [])
    }

    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://any-url.com")!
        let (sut, httpClient) = makeSUT(url: url)

        sut.load { _ in }

        XCTAssertEqual(httpClient.requestedURLs, [url])
    }

    func test_loadTwice_requestsTwiceDataFromURL() {
        let url = URL(string: "https://any-url.com")!
        let (sut, httpClient) = makeSUT(url: url)

        sut.load { _ in }
        sut.load { _ in }

        XCTAssertEqual(httpClient.requestedURLs, [url, url])
    }

    func test_load_returnsErrorOnClientError() {
        let (sut, httpClient) = makeSUT()

        let exp = expectation(description: "Waiting for load to finish")

        sut.load { result in
            switch result {
            case .failure(let error):
                XCTAssertEqual(error, .clientError)
            case .success:
                XCTFail("Got \(result) instead of failure")
            }
            exp.fulfill()
        }

        httpClient.completeWithError(at: 0)

        wait(for: [exp], timeout: 1)
    }

    // MARK: - Test Helpers

    private func makeSUT(url: URL = URL(string: "https://given-url.com")!, file: StaticString = #filePath, line: UInt = #line) -> (sut: BreweryRemoteLoader, httpClient: HTTPClientSpy) {
        let httpClient = HTTPClientSpy()
        let sut = BreweryRemoteLoader(httpClient: httpClient, url: url)
        addTeardownBlock { [weak httpClient, weak sut] in
            XCTAssertNil(httpClient, "HTTP Client is not deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(sut, "Brewery Remote Loader is not deallocated. Potential memory leak.", file: file, line: line)
        }
        return (sut, httpClient)
    }
}
