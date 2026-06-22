import Network

protocol NetworkPathProviding: AnyObject {
    var pathUpdateHandler: (@Sendable (NWPath) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

extension NWPathMonitor: NetworkPathProviding {}
