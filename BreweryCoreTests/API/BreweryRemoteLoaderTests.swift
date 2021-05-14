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

        sut.load(for: "") { _ in }

        XCTAssertEqual(httpClient.requestedURLs, [url])
    }

    func test_loadTwice_requestsTwiceDataFromURL() {
        let url = URL(string: "https://any-url.com")!
        let (sut, httpClient) = makeSUT(url: url)

        sut.load(for: "") { _ in }
        sut.load(for: "") { _ in }

        XCTAssertEqual(httpClient.requestedURLs, [url, url])
    }

    func test_load_returnsErrorOnClientError() {
        let (sut, httpClient) = makeSUT()

        assert(sut, toCompleteWithResult: failure(.clientError), when: {
            httpClient.completeWithError(at: 0)
        })
    }
    
    func test_load_returnsErrorOnInvalidHTTPResponse() {
        let (sut, httpClient) = makeSUT()

        assert(sut, toCompleteWithResult: failure(.invalidData), when: {
            httpClient.complete(withStatusCode: 400, data: Data(), at: 0)
        })
    }
    
    func test_load_returnsErrorOnInvalidJSON() {
        let (sut, httpClient) = makeSUT()

        assert(sut, toCompleteWithResult: failure(.invalidData), when: {
            httpClient.complete(withStatusCode: 200, data: makeInvalidJSON(), at: 0)
        })
    }
    
    func test_load_returnsEmptyResultsOnEmptyJSONArray() {
        let (sut, httpClient) = makeSUT()

        assert(sut, toCompleteWithResult: .success([]), when: {
            httpClient.complete(withStatusCode: 200, data: makeEmptyJSON(), at: 0)
        })
    }
    
    func test_load_returnsBreweriesOnValidJSON() {
        let (sut, httpClient) = makeSUT()

        assert(sut, toCompleteWithResult: .success(makeBreweries()), when: {
            httpClient.complete(withStatusCode: 200, data: makeValidJSON(), at: 0)
        })
    }
}

// MARK: - Test Helpers
private extension BreweryRemoteLoaderTests {
    func makeSUT(url: URL = URL(string: "https://given-url.com")!, file: StaticString = #filePath, line: UInt = #line) -> (sut: BreweryRemoteLoader, httpClient: HTTPClientSpy) {
        let httpClient = HTTPClientSpy()
        let sut = BreweryRemoteLoader(httpClient: httpClient, url: url)
        trackForMemoryLeak(httpClient, file: file, line: line)
        trackForMemoryLeak(sut, file: file, line: line)
        return (sut, httpClient)
    }

    func failure(_ error: BreweryRemoteLoader.Error) -> Result<[Brewery], Error> {
        return .failure(error)
    }
    
    func assert(_ sut: BreweryRemoteLoader, toCompleteWithResult expectedResult: BreweryRemoteLoader.Result, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Waiting for load to finish")

        sut.load(for: "") { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedBreweries), .success(expectedBreweries)):
                XCTAssertEqual(receivedBreweries, expectedBreweries, file: file, line: line)
            case let (.failure(receivedError as BreweryRemoteLoader.Error), .failure(expectedError as BreweryRemoteLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected result \(expectedResult), got \(receivedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 1)
    }

    func makeInvalidJSON() -> Data {
        "invalid_json".data(using: .utf8)!
    }

    func makeEmptyJSON() -> Data {
        "[]".data(using: .utf8)!
    }

    func makeValidJSON() -> Data {
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

    func makeBreweries() -> [Brewery] {
        [
            Brewery(name: "Bnaf, LLC", street: nil, city: "Austin", state: "Texas"),
            Brewery(name: "Boulder Beer Co", street: "2880 Wilderness Pl", city: "Boulder", state: "Colorado")
        ]
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
