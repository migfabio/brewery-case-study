import BreweryCore
import XCTest

class URLSessionHTTPClient: HTTPClient {
    private struct InvalidRepresentation: Error {}
    
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get(from url: URL, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        session.dataTask(with: url) { _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(InvalidRepresentation()))
            }
        }.resume()
    }
}

final class URLSessionHTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(URLProtocolStub.self)
    }
    
    override func tearDown() {
        super.tearDown()
        URLProtocol.unregisterClass(URLProtocolStub.self)
        URLProtocolStub.data = nil
        URLProtocolStub.response = nil
        URLProtocolStub.error = nil
    }
    
    func test_get_failsOnRequestError() {
        let expectedError = anyError()
        let receivedError = errorFor(data: nil, response: nil, error: expectedError) as NSError?
        
        XCTAssertEqual(receivedError?.domain, expectedError.domain)
        XCTAssertEqual(receivedError?.code, expectedError.code)
    }
    
    func test_get_failsOnInvalidStates() {
        XCTAssertNotNil(errorFor(data: nil, response: nil, error: nil))
        XCTAssertNotNil(errorFor(data: nil, response: anyNonHTTPURLResponse(), error: nil))
        XCTAssertNotNil(errorFor(data: anyData(), response: nil, error: nil))
        XCTAssertNotNil(errorFor(data: anyData(), response: nil, error: anyError()))
        XCTAssertNotNil(errorFor(data: nil, response: anyNonHTTPURLResponse(), error: anyError()))
        XCTAssertNotNil(errorFor(data: nil, response: anyHTTPURLResponse(), error: anyError()))
        XCTAssertNotNil(errorFor(data: anyData(), response: anyHTTPURLResponse(), error: anyError()))
        XCTAssertNotNil(errorFor(data: anyData(), response: anyNonHTTPURLResponse(), error: anyError()))
        XCTAssertNotNil(errorFor(data: anyData(), response: anyNonHTTPURLResponse(), error: nil))
    }
}

private extension URLSessionHTTPClientTests {
    func anyURL() -> URL {
        return URL(string: "https://any-url.com")!
    }
    
    func anyNonHTTPURLResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    
    func anyData() -> Data {
        return "some_data".data(using: .utf8)!
    }
    
    func anyError() -> NSError {
        return NSError(domain: "", code: 0)
    }
    
    func resultFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> Result<(Data, HTTPURLResponse), Error> {
        let url = anyURL()
        
        URLProtocolStub.data = data
        URLProtocolStub.response = response
        URLProtocolStub.error = error
        
        let sut = URLSessionHTTPClient()

        let exp = expectation(description: "Waiting for completion")

        var receivedResult: Result<(Data, HTTPURLResponse), Error>!
        sut.get(from: url) { result in
            receivedResult = result
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
        return receivedResult
    }
    
    func errorFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)
        
        switch result {
        case let .failure(error):
            return error
        default:
            XCTFail("Expected failure, received \(result) instead", file: file, line: line)
            return nil
        }
    }

    final class URLProtocolStub: URLProtocol {
        static var data: Data?
        static var response: URLResponse?
        static var error: Error?

        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            if let data = URLProtocolStub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let response = URLProtocolStub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let error = URLProtocolStub.error {
                client?.urlProtocol(self, didFailWithError: error)
            }

            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
}
