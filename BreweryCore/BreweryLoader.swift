import Foundation

protocol BreweryLoader {
    func load(for state: String, completion: @escaping (Result<[Brewery], Error>) -> Void)
}
