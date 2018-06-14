import Foundation

public struct AnyBsonValue: Codable {
    let value: BsonValue

    public init(_ value: BsonValue) {
        self.value = value
    }

    public func encode(to encoder: Encoder) throws {
        if let arr = self.value as? [BsonValue?] {
            let mapped = arr.map { elt in
                return elt == nil ? nil : AnyBsonValue(elt!)
            }
            try mapped.encode(to: encoder)
        } else {
            try self.value.encode(to: encoder)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Binary.self) {
            self.value = value
        } else if let value = try? container.decode(ObjectId.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(Date.self) {
            self.value = value
        } else if let value = try? container.decode(RegularExpression.self) {
            self.value = value
        } else if let value = try? container.decode(CodeWithScope.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Int32.self) {
            self.value = value
        } else if let value = try? container.decode(Int64.self) {
            self.value = value
        } else if let value = try? container.decode(Decimal128.self) {
            self.value = value
        } else if let value = try? container.decode(MinKey.self) {
            self.value = value
        } else if let value = try? container.decode(MaxKey.self) {
            self.value = value
        } else if let value = try? container.decode([AnyBsonValue?].self) {
            self.value = value.map { elt in 
                return elt == nil ? nil : elt!.value
            }
        } else if let value = try? container.decode(Document.self) {
            self.value = value
        } else {
            throw MongoError.typeError(
                message: "Encountered a value that could not be decoded to any BSON type")
        }
    }
}
