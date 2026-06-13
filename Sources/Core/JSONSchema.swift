import Foundation

// MARK: - JSONType

/// The primitive types supported in a JSON Schema definition.
@frozen
enum JSONType: String, Codable, CaseIterable {
    case string
    case number
    case integer
    case boolean
    case object
    case array
}

// MARK: - JSONProperty

/// A single property definition within a JSON Schema object.
struct JSONProperty: Codable {

    /// The property name.
    let name: String

    /// The JSON type of this property.
    let type: JSONType

    /// A human-readable description of the property's purpose.
    let description: String

    /// Whether this property is required in the schema.
    let required: Bool

    /// Allowed enum values, if the property is constrained.
    var enumValues: [String]?

    /// For array types, the schema of the items within the array.
    var items: JSONSchema?

    // MARK: - Initialization

    init(
        name: String,
        type: JSONType,
        description: String,
        required: Bool = false,
        enumValues: [String]? = nil,
        items: JSONSchema? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.enumValues = enumValues
        self.items = items
    }

    // MARK: - Dictionary Conversion

    /// Converts this property into its JSON Schema representation
    /// as a dictionary suitable for `JSONSerialization`.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "description": description,
        ]
        if let enumValues = enumValues {
            dict["enum"] = enumValues
        }
        if let items = items {
            dict["items"] = items.toDictionary()
        }
        return dict
    }
}

// MARK: - JSONSchema

/// Describes the expected shape of a tool's input parameters
/// using a subset of JSON Schema (draft-07 compatible).
///
/// This is used to generate the `function.parameters` field in
/// OpenAI/Anthropic tool definitions.
struct JSONSchema: Codable {

    /// The root type of the schema. Typically `.object` for
    /// tool parameter definitions.
    let type: JSONType

    /// The ordered list of properties for object-type schemas.
    var properties: [JSONProperty]

    /// The names of properties that are required.
    var required: [String]

    // MARK: - Initialization

    init(
        type: JSONType = .object,
        properties: [JSONProperty] = [],
        required: [String] = []
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }

    // MARK: - Dictionary Conversion

    /// Converts the full schema into a dictionary suitable for
    /// `JSONSerialization`, producing valid JSON Schema output.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
        ]

        if !properties.isEmpty {
            var propsDict: [String: Any] = [:]
            for property in properties {
                propsDict[property.name] = property.toDictionary()
            }
            dict["properties"] = propsDict
        }

        if !required.isEmpty {
            dict["required"] = required
        }

        return dict
    }
}
