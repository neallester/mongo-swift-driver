import Foundation

extension Document: Codable {
	public func encode(to encoder: Encoder) throws {
		if let bsonEncoder = encoder as? _BsonEncoder {
			bsonEncoder.storage.containers.append(self)
			return
		}

		var container = encoder.container(keyedBy: _BsonKey.self)
		for (k, v) in self {
			let key = _BsonKey(stringValue: k)!
			if let val = v {
				try container.encode(AnyBsonValue(val), forKey: key)
			} else {
				try container.encodeNil(forKey: key)
			}
		}
	}

	public init(from decoder: Decoder) throws {
		// if it's a BsonDecoder we should just short-circuit and return the container document
		if let bsonDecoder = decoder as? _BsonDecoder {
			let topContainer = bsonDecoder.storage.topContainer
			guard let doc = topContainer as? Document else {
				throw DecodingError._typeMismatch(at: [], expectation: Document.self, reality: topContainer)
			}
			self = doc
		// Otherwise get a keyed container and decode each key one by one
		} else {
			let container = try decoder.container(keyedBy: _BsonKey.self)
			var output = Document()
			for key in container.allKeys {
				let k = key.stringValue
				if try container.decodeNil(forKey: key) {
					output[k] = nil
				} else {
					output[k] = try container.decode(AnyBsonValue.self, forKey: key).value
				}
			}
			self = output
		}
	}
}
