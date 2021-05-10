import Foundation

protocol BreweryLoader {
    func getBreweries(for state: String, completion: Result<[Brewery], Error>)
}
