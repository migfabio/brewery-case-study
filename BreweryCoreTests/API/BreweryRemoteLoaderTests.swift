import XCTest

protocol HTTPClient {
    func get(from url: URL, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void)
}

final class BreweryRemoteLoader {
    private let httpClient: HTTPClient
    private let url: URL

    enum Error: Swift.Error, Equatable {
        case clientError
        case invalidData
    }

    init(httpClient: HTTPClient, url: URL) {
        self.httpClient = httpClient
        self.url = url
    }

    func load(completion: @escaping (Result<Void, Error>) -> Void) {
        httpClient.get(from: url) { result in
            switch result {
            case .failure:
                completion(.failure(.clientError))
            case .success:
                completion(.failure(.invalidData))
            }

        }
    }
}

final class HTTPClientSpy: HTTPClient {
    private var requests = [(url: URL, completion: (Result<HTTPURLResponse, Error>) -> Void)]()

    var requestedURLs: [URL] {
        requests.map { $0.url }
    }
    
    func get(from url: URL, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        self.requests.append((url, completion))
    }

    func completeWithError(at index: Int) {
        requests[index].completion(.failure(NSError(domain: "", code: 0)))
    }
    
    func completeWithInvalidStatusCode(at index: Int) {
        let response = HTTPURLResponse(url: requestedURLs[index], statusCode: 400, httpVersion: nil, headerFields: nil)!
        requests[index].completion(.success(response))
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
        assert(sut, toCompleteWithError: .clientError, when: { httpClient.completeWithError(at: 0) })
    }
    
    func test_load_returnsErrorOnInvalidHTTPResponse() {
        let (sut, httpClient) = makeSUT()
        assert(sut, toCompleteWithError: .invalidData, when: { httpClient.completeWithInvalidStatusCode(at: 0) })
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
    
    private func assert(_ sut: BreweryRemoteLoader, toCompleteWithError expectedError: BreweryRemoteLoader.Error, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Waiting for load to finish")

        sut.load { result in
            switch result {
            case .failure(let receivedError):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            case .success:
                XCTFail("Got \(result) instead of failure with \(expectedError)", file: file, line: line)
            }
            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 1)
    }
}
