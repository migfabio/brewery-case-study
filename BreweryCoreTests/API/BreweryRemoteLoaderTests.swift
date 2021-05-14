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
        assert(sut, toCompleteWithError: .clientError, when: {
            httpClient.completeWithError(at: 0)
        })
    }
    
    func test_load_returnsErrorOnInvalidHTTPResponse() {
        let (sut, httpClient) = makeSUT()
        assert(sut, toCompleteWithError: .invalidData, when: {
            httpClient.complete(withStatusCode: 400, data: Data(), at: 0)
        })
    }
    
    func test_load_returnsErrorOnInvalidJSON() {
        let (sut, httpClient) = makeSUT()
        let invalidData = "invalid_json".data(using: .utf8)!
        assert(sut, toCompleteWithError: .invalidData, when: {
            httpClient.complete(withStatusCode: 200, data: invalidData, at: 0)
        })
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

        let emptyJSON = "[]".data(using: .utf8)!
        httpClient.complete(withStatusCode: 200, data: emptyJSON, at: 0)

        wait(for: [exp], timeout: 1)
    }
    
    func test_load_returnsBreweriesOnValidJSON() {
        let (sut, httpClient) = makeSUT()
        
        let exp = expectation(description: "Waiting for load to finish")

        sut.load { result in
            switch result {
            case .failure(let receivedError):
                XCTFail("Got failure of type \(receivedError) instead of success")
            case .success(let breweries):
                XCTAssertEqual(breweries, [
                                Brewery(name: "Bnaf, LLC", street: nil, city: "Austin", state: "Texas"),
                                Brewery(name: "Boulder Beer Co", street: "2880 Wilderness Pl", city: "Boulder", state: "Colorado")
                ])
            }
            exp.fulfill()
        }
        
        httpClient.complete(withStatusCode: 200, data: makeJSONResponse(), at: 0)

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

    func makeJSONResponse() -> Data {
        """
            [
                {
                    "id": 9094,
                    "obdb_id": "bnaf-llc-austin",
                    "name": "Bnaf, LLC",
                    "brewery_type": "planning",
                    "street": null,
                    "address_2": null,
                    "address_3": null,
                    "city": "Austin",
                    "state": "Texas",
                    "county_province": null,
                    "postal_code": "78727-7602",
                    "country": "United States",
                    "longitude": null,
                    "latitude": null,
                    "phone": null,
                    "website_url": null,
                    "updated_at": "2018-07-24T00:00:00.000Z",
                    "created_at": "2018-07-24T00:00:00.000Z"
                },
                {
                    "id": 9180,
                    "obdb_id": "boulder-beer-co-boulder",
                    "name": "Boulder Beer Co",
                    "brewery_type": "regional",
                    "street": "2880 Wilderness Pl",
                    "address_2": null,
                    "address_3": null,
                    "city": "Boulder",
                    "state": "Colorado",
                    "county_province": null,
                    "postal_code": "80301-5401",
                    "country": "United States",
                    "longitude": "-105.2480158",
                    "latitude": "40.026439",
                    "phone": null,
                    "website_url": null,
                    "updated_at": "2018-08-24T00:00:00.000Z",
                    "created_at": "2018-07-24T00:00:00.000Z"
                }
            ]
        """.data(using: .utf8)!
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

        func complete(withStatusCode code: Int, data: Data, at index: Int) {
            let response = HTTPURLResponse(
                url: requestedURLs[index],
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            requests[index].completion(.success((data, response)))
        }
    }
}
