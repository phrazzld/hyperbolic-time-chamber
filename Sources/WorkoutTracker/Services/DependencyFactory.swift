import Foundation

/// Factory for creating app dependencies with proper configuration
public struct DependencyFactory {

    /// Configuration options for dependency creation
    public struct Configuration {
        public let isDemo: Bool
        public let isScreenshotMode: Bool
        public let isUITesting: Bool
        public let fileManager: FileManager
        public let baseDirectory: URL?

        public init(
            isDemo: Bool = false,
            isScreenshotMode: Bool = false,
            isUITesting: Bool = false,
            fileManager: FileManager = .default,
            baseDirectory: URL? = nil
        ) {
            self.isDemo = isDemo
            self.isScreenshotMode = isScreenshotMode
            self.isUITesting = isUITesting
            self.fileManager = fileManager
            self.baseDirectory = baseDirectory
        }

        /// Creates a configuration from the current process environment
        public static var fromEnvironment: Configuration {
            Configuration(
                isDemo: DemoDataService.isDemoMode,
                isScreenshotMode: DemoDataService.isScreenshotMode,
                isUITesting: DemoDataService.isUITesting
            )
        }
    }

    /// Creates a data store based on the provided configuration
    public static func createDataStore(configuration: Configuration) -> DataStoreProtocol {
        // Use in-memory store for demo/testing scenarios
        if configuration.isDemo || configuration.isScreenshotMode || configuration.isUITesting {
            return InMemoryDataStore()
        }

        // Use file-based store for production
        return FileDataStore(
            fileManager: configuration.fileManager,
            baseDirectory: configuration.baseDirectory
        )
    }

    /// Creates a view model with the appropriate data store
    public static func createViewModel(configuration: Configuration = .fromEnvironment) -> WorkoutViewModel {
        let dataStore = createDataStore(configuration: configuration)
        return WorkoutViewModel(dataStore: dataStore)
    }

    /// Creates a view model with a custom data store (useful for testing)
    public static func createViewModel(dataStore: DataStoreProtocol) -> WorkoutViewModel {
        WorkoutViewModel(dataStore: dataStore)
    }
}
