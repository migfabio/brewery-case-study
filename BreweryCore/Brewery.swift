import Foundation

public struct Brewery: Equatable {
    public let name: String
    public let street: String?
    public let city: String
    public let state: String
    
    public init(name: String, street: String?, city: String, state: String) {
        self.name = name
        self.street = street
        self.city = city
        self.state = state
    }
}
