//
//  URLSessionHTTPClient.swift
//  BreweryCore
//
//  Created by Christopher La Pat on 14/05/2021.
//

import Foundation

public final class URLSessionHTTPClient: HTTPClient {
    private struct InvalidRepresentation: Error {}
    
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(from url: URL, completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = data, let response = response as? HTTPURLResponse {
                completion(.success((data, response)))
            } else {
                completion(.failure(InvalidRepresentation()))
            }
        }.resume()
    }
}
