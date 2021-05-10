import BreweryCore
import XCTest

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
    
    func test_load_returnsErrorOnInvalidJSON() {
        let (sut, httpClient) = makeSUT()
        assert(sut, toCompleteWithError: .invalidData, when: { httpClient.completeWithInvalidJSON(at: 0) })
    }
    
    func test_load_returnsEmptyResultsOnEmptyJSONArray() {
        let (sut, httpClient) = makeSUT()
        
        let exp = expectation(description: "Waiting for load to finish")

        sut.load { result in
            switch result {
            case .failure(let receivedError):
                XCTFail("Got failure of type \(receivedError) instead of success")
            case .success(let breweries):
                XCTAssertEqual(breweries, [])
            }
            exp.fulfill()
        }
        
        httpClient.completeWithEmptyJSONArray(at: 0)

        wait(for: [exp], timeout: 1)
    }
}

// MARK: - Test Helpers
private extension BreweryRemoteLoaderTests {
    func makeSUT(url: URL = URL(string: "https://given-url.com")!, file: StaticString = #filePath, line: UInt = #line) -> (sut: BreweryRemoteLoader, httpClient: HTTPClientSpy) {
        let httpClient = HTTPClientSpy()
        let sut = BreweryRemoteLoader(httpClient: httpClient, url: url)
        addTeardownBlock { [weak httpClient, weak sut] in
            XCTAssertNil(httpClient, "HTTP Client is not deallocated. Potential memory leak.", file: file, line: line)
            XCTAssertNil(sut, "Brewery Remote Loader is not deallocated. Potential memory leak.", file: file, line: line)
        }
        return (sut, httpClient)
    }
    
    func assert(_ sut: BreweryRemoteLoader, toCompleteWithError expectedError: BreweryRemoteLoader.Error, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
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
    
    final class HTTPClientSpy: HTTPClient {
        private var requests = [(url: URL, completion: (Result<(Data, HTTPURLResponse), Error>) -> Void)]()

        var requestedURLs: [URL] {
            requests.map { $0.url }
        }
        
        func get(from url: URL, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
            self.requests.append((url, completion))
        }

        func completeWithError(at index: Int) {
            requests[index].completion(.failure(NSError(domain: "", code: 0)))
        }
        
        func completeWithInvalidStatusCode(at index: Int) {
            let response = HTTPURLResponse(url: requestedURLs[index], statusCode: 400, httpVersion: nil, headerFields: nil)!
            requests[index].completion(.success((Data(), response)))
        }
        
        func completeWithInvalidJSON(at index: Int) {
            let response = HTTPURLResponse(url: requestedURLs[index], statusCode: 200, httpVersion: nil, headerFields: nil)!
            let invalidJSON = "invalid_json_all_over_the_place".data(using: .utf8)!
            
            requests[index].completion(.success((invalidJSON, response)))
        }
        
        func completeWithEmptyJSONArray(at index: Int) {
            let response = HTTPURLResponse(url: requestedURLs[index], statusCode: 200, httpVersion: nil, headerFields: nil)!
            let emptyJSONArray = "[]".data(using: .utf8)!
            requests[index].completion(.success((emptyJSONArray, response)))
        }
    }
}
