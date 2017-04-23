import Foundation

public struct JWJSON {
    public enum Error: Swift.Error, CustomNSError {
        case mistyped(expected: Any.Type, found: Any.Type)
        case unsupportedType(Any.Type)
        case invalidJSON(Swift.Error?)
        case missingValue
        case invalidEncoding
        case underlying(Swift.Error?)
        
        public static let errorDomain = "JWJSON.Error"
        
        public var errorCode: Int {
            switch self {
            case .mistyped:
                return 1
            case .unsupportedType:
                return 2
            case .invalidJSON:
                return 3
            case .missingValue:
                return 4
            case .invalidEncoding:
                return 5
            case .underlying:
                return 6
            }
        }
        
        public var errorUserInfo: [String : Any] {
            switch self {
            case let .mistyped(expected: expected, found: found):
                return ["expected": expected, "found": found]
            case .unsupportedType(let type):
                return ["unsupported": type]
            case .invalidJSON(let error):
                guard let error = error else { return [:] }
                return [NSUnderlyingErrorKey: error]
            case .missingValue:
                return [:]
            case .invalidEncoding:
                return [:]
            case .underlying(let error):
                guard let error = error else { return [:] }
                return [NSUnderlyingErrorKey: error]
            }
        }
    }
    
    fileprivate enum Raw {
        case dictionary([String: Any])
        case array([Any])
        case string(String)
        /// Double representation, as specified in [RFC7159#Number](https://tools.ietf.org/html/rfc7159#section-6)
        case number(Double)
        case bool(Bool)
        case null
        case error(JWJSON.Error)
    }
    
    fileprivate var raw: Raw
    
    public init(parse string: String) {
        guard let data = string.data(using: .utf8) else {
            self.init(error: .invalidEncoding)
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
            self.init(json)
        } catch {
            self.init(error: .invalidJSON(error))
        }
    }
    
    public init(_ object: Any) {
        guard JSONSerialization.isValidJSONFragment(object) else {
            raw = .error(.invalidJSON(nil))
            return
        }
        
        switch object {
        case let x as [String: Any]:
            raw = .dictionary(x)
            
        case let x as [Any]:
            raw = .array(x)
            
        case let x as String:
            raw = .string(x)
            
        case let number as NSNumber:
            raw = number.isActuallyBool ? .bool(number.boolValue) : .number(number.doubleValue)
        case let x as Int:
            raw = .number(Double(x))
        case let x as Double:
            raw = .number(x)
        case let x as Float:
            raw = .number(Double(x))
            
        case let x as Bool:
            raw = .bool(x)
            
        case nil:
            fallthrough
        case is NSNull:
            raw = .null

        case let error as JWJSON.Error:
            raw = .error(error)
        case let error as Swift.Error:
            raw = .error(.underlying(error))

        default:
            raw = .error(.unsupportedType(type(of: object)))
        }
    }
    
    public static var null: JWJSON {
        return JWJSON(NSNull())
    }
    
    fileprivate init(error: JWJSON.Error) {
        raw = .error(error)
    }
}


// MARK: - Getters

extension JWJSON {
    public var dictionary: [String: JWJSON]? {
        get {
            guard case .dictionary(let dict) = raw else { return nil }
            
            return Dictionary(fromCollection: dict.map { ($0.key, JWJSON($0.value)) })
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            rawDictionary = Dictionary(fromCollection: newValue.map { ($0.key, $0.value.raw.object) })
        }
    }
    
    public var dictionaryValue: [String: JWJSON] {
        return dictionary ?? [:]
    }
    
    public var rawDictionary: [String: Any]? {
        get {
            guard case .dictionary(let dict) = raw else { return nil }
            return dict
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            
            guard JSONSerialization.isValidJSONObject(newValue) else {
                raw = .error(.invalidJSON(nil))
                return
            }
            
            raw = .dictionary(newValue)
        }
    }
    
    public var array: [JWJSON]? {
        get {
            guard case .array(let arr) = raw else { return nil }
            return arr.map { JWJSON($0) }
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            
            rawArray = newValue.map { $0.raw.object }
        }
    }
    
    public var arrayValue: [JWJSON] {
        return array ?? []
    }
    
    public var rawArray: [Any]? {
        get {
            guard case .array(let arr) = raw else { return nil }
            return arr
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            
            guard JSONSerialization.isValidJSONObject(newValue) else {
                raw = .error(.invalidJSON(nil))
                return
            }
            
            raw = .array(newValue)
        }
    }
    
    public var string: String? {
        get {
            guard case .string(let str) = raw else { return nil }
            return str
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            raw = .string(newValue)
        }
    }
    
    public var stringValue: String {
        return string ?? ""
    }
    
    public var double: Double? {
        get {
            guard case .number(let num) = raw else { return nil }
            return num
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            raw = .number(newValue)
        }
    }
    
    public var doubleValue: Double {
        return double ?? 0
    }
    
    /// Numbers are stored as `Double`, as specified by [Number in RFC7159](https://tools.ietf.org/html/rfc7159#section-6) , so max/min range will not be the usual `Int.max`/`Int.min`
    public var int: Int? {
        get {
            guard case .number(let num) = raw else { return nil }
            return Int(num)
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            raw = .number(Double(newValue))
        }
    }
    
    /// Numbers are stored as `Double`, as specified by [Number in RFC7159](https://tools.ietf.org/html/rfc7159#section-6) , so max/min range will not be the usual `Int.max`/`Int.min`
    public var intValue: Int {
        return int ?? 0
    }
    
    public var bool: Bool? {
        get {
            guard case .bool(let bool) = raw else { return nil }
            return bool
        }
        set {
            guard let newValue = newValue else {
                raw = .null
                return
            }
            raw = .bool(newValue)
        }
    }
    
    public var boolValue: Bool {
        return bool ?? false
    }
    
    public var isNull: Bool {
        guard case .null = raw else { return false }
        return true
    }
    
    public var error: JWJSON.Error? {
        guard case .error(let error) = raw else { return nil }
        return error
    }
}


// MARK: - Subscripting

extension JWJSON {
    public enum SubscriptKey {
        case dictionaryKey(String)
        case arrayIndex(Int)
    }
    
    
    /// Gets/sets a value at a given index or indexes
    ///
    /// Based on the following json output:
    ///
    ///     {
    ///       "people" : [
    ///         {
    ///           "name" : "Bob Lee Swagger"
    ///         },
    ///         {
    ///           "name" : "Colonel Isaac Johnson"
    ///         }
    ///       ]
    ///     }
    ///
    /// The following are valid
    ///
    ///     json["people"]
    ///     // JWJSON.array([["name": "Bob Lee Swagger", "age": 47], ["name": "Colonel Isaac Johnson"]])
    ///     json["people"][0]
    ///     // JWJSON.dictionary(["name": "Bob Lee Swagger"])
    ///     json["people"][0]["name"]
    ///     // JWJSON.string(Bob Lee Swagger)
    ///
    /// But these calls are not, and will return an error contained in a JSON
    /// 
    ///     json["Waldo"]
    ///     // JWJSON.error(missingValue)
    ///     json[0]
    ///     // JWJSON.error(mistyped(expected: Swift.Array<Any>, found: Swift.Dictionary<Swift.String, Any>))
    ///     json["people", 2]
    ///     // JWJSON.error(missingValue)
    ///     json["people", 0, "name", 0]
    ///     // JWJSON.error(mistyped(expected: Swift.Array<Any>, found: Swift.String))
    ///
    /// - note: `json["people", 0]` is equivalent to `json["people"][0]`
    ///
    /// - Parameter keys: one or more elements that can be converted to an index/key (i.e. `Int` or `String`)
    public subscript(keys: JWJSONSubscriptable...) -> JWJSON {
        get {
            return self[keys.map { $0.jsonKey }]
        }
        set {
            self[keys.map { $0.jsonKey }] = newValue
        }
    }
    
    private subscript(keys: [SubscriptKey]) -> JWJSON {
        get {
            guard error == nil else { return self }
            
            switch keys.first {
            case .some(.dictionaryKey(let key)):
                return self[string: key][Array(keys.dropFirst())]
                
            case .some(.arrayIndex(let index)):
                return self[int: index][Array(keys.dropFirst())]
                
            case .none:
                return self
            }
        }
        set {
            guard error == nil else { return }
            
            switch keys.first {
            case .some(.dictionaryKey(let key)):
                self[string: key][Array(keys.dropFirst())] = newValue
                
            case .some(.arrayIndex(let index)):
                self[int: index][Array(keys.dropFirst())] = newValue
                
            case .none:
                raw = newValue.raw
            }
        }
    }
    
    private subscript(string key: String) -> JWJSON {
        get {
            guard error == nil else { return self }
            
            guard case .dictionary(let dictionary) = raw else { return JWJSON(error: .mistyped(expected: [String: Any].self, found: raw.type)) }
            guard let element = dictionary[key] else { return JWJSON(error: .missingValue) }
            
            return JWJSON(element)
        }
        set {
            guard error == nil else { return }
            
            rawDictionary?[key] = newValue.raw.object
        }
    }
    
    private subscript(int index: Int) -> JWJSON {
        get {
            guard error == nil else { return self }
            
            guard case .array(let arr) = raw else { return JWJSON(error: .mistyped(expected: [Any].self, found: raw.type)) }
            guard arr.indices.contains(index) else { return JWJSON(error: .missingValue) }
            
            return JWJSON(arr[index])
        }
        set {
            guard error == nil, case .array(let array) = raw else { return }
            
            guard array.indices.contains(index) else { return }
            
            // Assign to `rawArray`. Otherwise only modifying local copy?
            rawArray?[index] = newValue.raw.object
        }
    }
}


// MARK: Subscriptable keys

/// Represents an individual key or index that can subscript JWJSON
public protocol JWJSONSubscriptable {
    var jsonKey: JWJSON.SubscriptKey { get }
}

extension String: JWJSONSubscriptable {
    public var jsonKey: JWJSON.SubscriptKey {
        return .dictionaryKey(self)
    }
}

extension Int: JWJSONSubscriptable {
    public var jsonKey: JWJSON.SubscriptKey {
        return .arrayIndex(self)
    }
}


// MARK: - Raw Types

private extension JWJSON.Raw {
    var type: Any.Type {
        switch self {
        case .dictionary:
            return [String: Any].self
        case .array:
            return [Any].self
        case .string:
            return String.self
        case .number:
            return Double.self
        case .bool:
            return Bool.self
        case .null:
            return NSNull.self
        case .error:
            return JWJSON.Error.self
        }
    }
    
    var object: Any {
        switch self {
        case .dictionary(let x):
            return x
            
        case .array(let x):
            return x
            
        case .string(let x):
            return x
            
        case .number(let x):
            return x
            
        case .bool(let x):
            return x
            
        case .null:
            return NSNull()
            
        case .error(let x):
            return x
        }
    }
}


// MARK: - CustomStringConvertible, CustomDebugConvertible

extension JWJSON: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return rawString() ?? "<Error: invalid JWJSON raw state (most likely an unexpected type or missing key/value)>"
    }
    
    public var debugDescription: String {
        switch raw {
        case .dictionary(let x):
            let children = x//.map { $0.key + ": " + JWJSON($0.value).debugDescription }
            return "JWJSON.dictionary(\(children))"
            
        case .array(let x):
            let children = x//.map { JWJSON($0).debugDescription }
            return "JWJSON.array(\(children))"
            
        case .string(let x):
            return "JWJSON.string(\(x))"
            
        case .number(let x):
            return "JWJSON.number(\(x))"
            
        case .bool(let x):
            return "JWJSON.bool(\(x))"
            
        case .null:
            return "JWJSON.null"
            
        case .error(let error):
            return "JWJSON.error(\(error))"
        }
    }
}


// MARK: - Printing JSON

extension JWJSON {
    public func rawString(encoding: String.Encoding = .utf8, options: JSONSerialization.WritingOptions = .prettyPrinted) -> String? {
        switch raw {
        case .dictionary(let x):
            do {
                return String(data: try JSONSerialization.data(withJSONObject: x, options: options), encoding: encoding)
            } catch {
                return nil
            }
            
        case .array(let x):
            do {
                return String(data: try JSONSerialization.data(withJSONObject: x, options: options), encoding: encoding)
            } catch {
                return nil
            }
            
        case .string(let string):
            return string
            
        case .number(let number):
            return String(number)
            
        case .bool(let bool):
            return String(bool)
            
        case .null:
            return "null"
            
        case .error:
            return nil
        }
    }
}


// MARK: - Equatable

extension JWJSON: Equatable {
    public static func == (lhs: JWJSON, rhs: JWJSON) -> Bool {
        switch lhs.raw {
        case .dictionary(let x):
            guard case .dictionary(let y) = rhs.raw else { return false }
            return (x as NSDictionary).isEqual(to: y) // [String: Any] does not have a == method. NSDictionary does, so..
            
        case .array(let x):
            guard case .array(let y) = rhs.raw else { return false }
            return (x as NSArray).isEqual(to: y) // [Any] does not have a == method. NSArray does, so..
            
        case .string(let x):
            guard case .string(let y) = rhs.raw else { return false }
            return x == y
        
        case .number(let x):
            guard case .number(let y) = rhs.raw else { return false }
            return x == y
            
        case .bool(let x):
            guard case .bool(let y) = rhs.raw else { return false }
            return x == y
            
        case .null:
            guard case .null = rhs.raw else { return false }
            return true
            
        case .error(_):
            return false
        }
    }
}


// MARK: - ExpressibleBy...Literal

extension JWJSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = [String: Any](fromCollection: elements)
        
        self.init(dictionary)
    }
}

extension JWJSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension JWJSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
}

extension JWJSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension JWJSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Float) {
        self.init(value)
    }
}

extension JWJSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}


// MARK: - Helper Extensions

private extension JSONSerialization {
    static func isValidJSONFragment(_ object: Any) -> Bool {
        guard object is NSArray || object is NSDictionary else {
            return JSONSerialization.isValidJSONObject([object])
        }
        return JSONSerialization.isValidJSONObject(object)
    }
}

private extension NSNumber {
    var isActuallyBool: Bool {
// TODO: SwiftyJSON uses this implementation. I've yet to test if either has any advantage over the other
//        let theNumberTrue = NSNumber(value: true)
//        let theNumberFalse = NSNumber(value: false)
//
//        let myObjCType = String(cString: objCType)
//        return (self == theNumberTrue && myObjCType == String(cString: theNumberTrue.objCType)) || (self == theNumberFalse && myObjCType == String(cString: theNumberFalse.objCType))
        
        return CFBooleanGetTypeID() == CFGetTypeID(self)
    }
}

private extension Dictionary {
    init<C: Collection>(fromCollection collection: C) where C.Iterator.Element == (Key, Value) {
        self.init(minimumCapacity: collection.underestimatedCount)
        
        for (k, v) in collection {
            self[k] = v
        }
    }
    
    init<C: Collection>(fromCollection collection: C) where C.Iterator.Element == (Key, Optional<Value>) {
        self.init(minimumCapacity: collection.underestimatedCount)
        
        for (k, v) in collection {
            self[k] = v
        }
    }
}




//let json: JWJSON = [
//       "people": [
//         [
//           "name": "Bob Lee Swagger",
//            "age": 47
//         ],
//         [
//           "name": "Colonel Isaac Johnson"
//         ]
//       ]
//     ]
//
//print(json)
//
//json["people"]
//debugPrint(json["people"])
//json["people"][0]
//debugPrint(json["people"][0])
//json["people"][0]["name"]
//debugPrint(json["people"][0]["name"])
//json["people", 0, "name"]
//debugPrint(json["people", 0, "name"])
//
//json["foo"]
//debugPrint(json["foo"])
//json[0]
//debugPrint(json[0])
//json["people", 2]
//debugPrint(json["people", 2])
//json["people"][0]["name"]
//debugPrint(json["people"][0]["name"][0])
//
//debugPrint(json["people", 0, "age"])
//
//
//
//print("caught")
//debugPrint(JWJSON(error: .missingValue))
//print(JWJSON(error: .missingValue))







