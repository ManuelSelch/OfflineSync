public enum ServiceError: Error {
    case unknown(String)
    case decodeFailed
    case remoteMethodNotDefined
}
