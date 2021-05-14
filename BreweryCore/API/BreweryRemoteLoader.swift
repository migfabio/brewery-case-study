import Foundation

public final class BreweryRemoteLoader: BreweryLoader {
    private let httpClient: HTTPClient
    private let url: URL

    public typealias Result = Swift.Result<[Brewery], Swift.Error>
    
    public enum Error: Swift.Error, Equatable {
        case clientError
        case invalidData
    }
    
    private struct RemoteBrewery: Decodable {
        let name: String
        let street: String?
        let city: String
        let state: String
        
        func getBrewery() -> Brewery {
            return Brewery(name: name, street: street, city: city, state: state)
        }
    }
    
    public init(httpClient: HTTPClient, url: URL) {
        self.httpClient = httpClient
        self.url = url
    }
    
    public func load(completion: @escaping (Result) -> Void) {
        httpClient.get(from: url) { result in
            switch result {
            case .failure:
                completion(.failure(Error.clientError))
            case .success(let (data, response)):
                if let breweries = try? JSONDecoder().decode([RemoteBrewery].self, from: data),
                   response.statusCode == 200 {
                    completion(.success(breweries.map { $0.getBrewery() }))
                } else {
                    completion(.failure(Error.invalidData))
                }
            }
        }
    }
}
