import Foundation

public final class BreweryRemoteLoader {
    private let httpClient: HTTPClient
    private let url: URL
    
    public enum Error: Swift.Error, Equatable {
        case clientError
        case invalidData
    }
    
    public init(httpClient: HTTPClient, url: URL) {
        self.httpClient = httpClient
        self.url = url
    }
    
    public func load(completion: @escaping (Result<[Brewery], Error>) -> Void) {
        httpClient.get(from: url) { result in
            switch result {
            case .failure:
                completion(.failure(.clientError))
            case .success(let (data, response)):
                if let _ = try? JSONSerialization.jsonObject(with: data),
                   response.statusCode == 200 {
                    completion(.success([]))
                } else {
                    completion(.failure(.invalidData))
                }
            }
        }
    }
}
