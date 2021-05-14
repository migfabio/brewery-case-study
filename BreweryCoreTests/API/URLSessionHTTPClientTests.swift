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
    func test_get_failsOnRequestError() {
        URLProtocol.registerClass(URLProtocolStub.self)
        let url = URL(string: "https://any-url.com")!
        let expectedError = NSError(domain: "", code: 0)
        URLProtocolStub.error = expectedError

        let sut = URLSessionHTTPClient()

        let exp = expectation(description: "Waiting for completion")

        sut.get(from: url) { result in
            switch result {
            case let .failure(receivedError as NSError):
                XCTAssertEqual(receivedError.domain, expectedError.domain)
                XCTAssertEqual(receivedError.code, receivedError.code)
            default:
                XCTFail("Expected failure, got \(result) instead")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
        URLProtocolStub.unregisterClass(URLProtocolStub.self)
    }
    
    func test_get_failsOnInvalidStates() {
        URLProtocol.registerClass(URLProtocolStub.self)
        let url = URL(string: "https://any-url.com")!
        
        URLProtocolStub.data = nil
        URLProtocolStub.response = nil
        URLProtocolStub.error = nil
        

        let sut = URLSessionHTTPClient()

        let exp = expectation(description: "Waiting for completion")

        sut.get(from: url) { result in
            switch result {
            case let .failure(receivedError):
                XCTAssertNotNil(receivedError)
            default:
                XCTFail("Expected failure, got \(result) instead")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
        URLProtocolStub.unregisterClass(URLProtocolStub.self)
    }
}

private extension URLSessionHTTPClientTests {

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
