import Foundation

protocol BreweryLoader {
    func load(completion: @escaping (Result<[Brewery], Error>) -> Void)
}
