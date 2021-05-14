import BreweryCore
import XCTest

final class URLSessionHTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.register()
    }
    
    override func tearDown() {
        super.tearDown()
        URLProtocolStub.unregister()
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
    
    func test_get_succeedsOnRequestSuccessWithoutData() {
        let expectedResponse = anyHTTPURLResponse()
        let receivedValues = resultValuesFor(data: nil, response: expectedResponse, error: nil)
        let emptyData = Data()
        
        XCTAssertEqual(receivedValues?.data, emptyData)
        XCTAssertEqual(receivedValues?.response.statusCode, expectedResponse.statusCode)
        XCTAssertEqual(receivedValues?.response.url, expectedResponse.url)
    }
    
    func test_get_succeedsOnRequestSuccessWithData() {
        let expectedResponse = anyHTTPURLResponse()
        let expectedData = anyData()
        let receivedValues = resultValuesFor(data: expectedData, response: expectedResponse, error: nil)
        
        XCTAssertEqual(receivedValues?.data, expectedData)
        XCTAssertEqual(receivedValues?.response.statusCode, expectedResponse.statusCode)
        XCTAssertEqual(receivedValues?.response.url, expectedResponse.url)
    }

    func test_get_performsGETRequestWithURL() {
        let url = anyURL()

        let exp = expectation(description: "Waiting for result")

        URLProtocolStub.spyRequest = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url, url)
            exp.fulfill()
        }

        makeSUT().get(from: url) { _ in }

        wait(for: [exp], timeout: 1.0)
    }
}

private extension URLSessionHTTPClientTests {
    func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> HTTPClient {
        let httpClient = URLSessionHTTPClient()
        trackForMemoryLeak(httpClient, file: file, line: line)
        return httpClient
    }

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
        
        let exp = expectation(description: "Waiting for completion")

        var receivedResult: Result<(Data, HTTPURLResponse), Error>!
        makeSUT().get(from: url) { result in
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
    
    func resultValuesFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> (data: Data, response: HTTPURLResponse)? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)
        
        switch result {
        case let .success(values):
            return values
        default:
            XCTFail("Expected success, received \(result) instead", file: file, line: line)
            return nil
        }
    }

    final class URLProtocolStub: URLProtocol {
        static var data: Data?
        static var response: URLResponse?
        static var error: Error?

        static var spyRequest: ((URLRequest) -> Void)?
        
        static func register() {
            URLProtocol.registerClass(URLProtocolStub.self)
        }
        
        static func unregister() {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            URLProtocolStub.data = nil
            URLProtocolStub.response = nil
            URLProtocolStub.error = nil
            URLProtocolStub.spyRequest = nil
        }

        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            if let spyRequest = URLProtocolStub.spyRequest {
                client?.urlProtocolDidFinishLoading(self)
                spyRequest(request)
                return
            }

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
