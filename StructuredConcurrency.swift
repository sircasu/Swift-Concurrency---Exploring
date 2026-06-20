import Foundation
import Playgrounds

#Playground {
    
    /// MARK: - models
    struct User: Codable {
        let id: Int
        let name: String
        let email: String
    }
    
    struct Post: Codable {
        let id: Int
        let userId: Int
        let title: String
        let body: String
    }
    
    struct UserResponse: Codable {
        let user: User
        let posts: [Post]
    }
    
    /// MARK: - api calls
    func fetchUser(id: Int) async throws -> User {
        
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/users/\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    
    
    func fetchPosts(id: Int) async throws -> [Post] {
        
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts?userId=\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Post].self, from: data)
    }
    
    
    // MARK: - Helper functions
    
    typealias UserResult = Swift.Result<UserResponse, Error>
    
    func loadUserProfileSendable(forUserId id: Int, completion: @escaping @Sendable (UserResult) -> Void ) {
        
        Task {
            do {
                let user = try await fetchUser(id: id)
                let posts = try await fetchPosts(id: id)
                let response = UserResponse(user: user, posts: posts)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
    
    func loadUserProfileMainActor(forUserId id: Int, completion: @escaping @MainActor (UserResult) -> Void) {
        
        Task {
            do {
                let user = try await fetchUser(id: id)
                let posts = try await fetchPosts(id: id)
                let response = UserResponse(user: user, posts: posts)
                await completion(.success(response))
            } catch {
                await completion(.failure(error))
            }
        }
    }
    
    
    func loadUserProfileSequential(forUserId id: Int) async throws -> UserResponse {
        // operation in sync
        let user = try await fetchUser(id: id)
        let posts = try await fetchPosts(id: id)
        return UserResponse(user: user, posts: posts)
    }
    
    
    func loadUserProfileConcurrently(forUserId: Int) async throws -> UserResponse {
        // operation in parallel
        async let user = fetchUser(id: forUserId) // Start task
        async let posts = fetchPosts(id: forUserId) // Start task
        
        // waith for both
        return UserResponse(
            user: try await user,
            posts: try await posts
        )
    }
    
    
    // MARK: - main
    print("=== Testing @Sendable Version ===")
    try await loadUserProfileSendable(forUserId: 1) { result in
        
        if case .success(let profile) = result {
            print("[Sendable] Main thread: \(Thread.isMainThread)") // could be false
        }
        
        
    }
    
    
    print("\n=== Testing @MainActor Version ===")
    try await loadUserProfileMainActor(forUserId: 2) { result in
        
        if case .success(let profile) = result {
            print("[MainActor] Main thread: \(Thread.isMainThread)") // always true
        }
    }
    
    
    print("\n=== Testing UserProfile Sequential Version ===")
    do {
        let profile = try await loadUserProfileSequential(forUserId: 3)
        print("profile", profile)
    } catch {
        print(error)
    }
    
    
    print("\n=== Testing UserProfile Concurrently Version ===")
    do {
        let profile = try await loadUserProfileConcurrently(forUserId: 4)
        print("profile", profile)
    } catch {
        print(error)
    }
    
    
    /// MARK: - Actors
    
    var currentTask: Task<Void, Never>?
    
    ///Waring: Main actor-isolated var 'currentTask' can not be mutated from a nonisolated context
    ///We have to mark it as @MainActor, or mark `currentTask` var as `nonisolated(unsafe)` to say to the compiler that we know what we are doing and that we are taking the responsability for thread safety.
    @MainActor func execute() {
        currentTask = Task {
            do {
                let profile = try await loadUserProfileConcurrently(forUserId: 1)
                print("User: \(profile.user.name), Post: \(profile.posts.count)")
            } catch {
                print("Failed to load profile: \(error)")
            }
        }
    }
    execute()
    
    
    
    /// User Profile manager
    
    class UserProfileManager {
        private var currentTask: Task<Void, Never>?
        
        func loadProfile(for userId: Int) {
            // cancel any existing task
            cancelCurrentLoad()
            
            currentTask = Task {
                do {
                    let profile = try await loadUserProfileConcurrently(forUserId: userId)
                    print("[UserProfileManager] User: \(profile.user.name), Post: \(profile.posts.count)")
                } catch {
                    print("[UserProfileManager] Failed to load profile: \(error)")
                }
            }
        }
        
        
        func cancelCurrentLoad() {
            currentTask?.cancel()
            currentTask = nil
        }
    }
    
    let profileManager = UserProfileManager()
    profileManager.loadProfile(for: 1)
    profileManager.cancelCurrentLoad()
    profileManager.loadProfile(for: 2)
    
    
    /// MARK: - Separate errors
    
    func loadProfileWithSeparateErrors(id: Int) async -> (User?, [Post]?, userError: Error?, postError: Error?) {
        
        
        async let userTask = fetchUser(id: id)
        async let postsTask = fetchPosts(id: id)
        
        
        var user: User?
        var posts: [Post]?
        var userError: Error?
        var postsError: Error?
        
        
        do {
            user = try await userTask
        } catch {
            userError = error
        }
        
        
        do {
            posts = try await postsTask
        } catch {
            postsError = error
        }
        
        
        
        return (user, posts, userError, postsError)
    }
    
    
    @MainActor
    class UserProfileManagerHandleDifferentErrors {
        
        private let shouldUserFail: Bool
        private let shouldPostsFail: Bool
        
        init(shouldUserFail: Bool, shouldPostsFail: Bool) {
            self.shouldUserFail = shouldUserFail
            self.shouldPostsFail = shouldPostsFail
        }
        
        func loadProfileWithSeparateErrors(id: Int) async -> (User?, [Post]?, userError: Error?, postsError: Error?) {

            async let userTask = self.fetchUser(id: id)
            async let postsTask = self.fetchPosts(id: id)

            var user: User?
            var posts: [Post]?

            var userError: Error?
            var postsError: Error?

            do {
                user = try await userTask
            } catch {
                userError = error
            }

            do {
                posts = try await postsTask
            } catch {
                postsError = error
            }

            return (user, posts, userError, postsError)
        }

        
        func loadProfile(for userId: Int) async {
            let (user, posts, userError, postsError) = await self.loadProfileWithSeparateErrors(id: userId)
            
            if let userError = userError {
                print("❌ User failed: \(userError)")
            }
            
            if let postsError = postsError {
                print("⚠️ Posts failed: \(postsError)")
            }
            
            if let user = user {
                print("✅ User: \(user.name)")
                if let posts = posts {
                    print("✅ Posts: \(posts.count)")
                } else {
                    print("⚠️ No posts available")
                }
            }
        }
        
        
        // MARK: Helpers
        func fetchUser(id: Int) async throws -> User {
            if shouldUserFail {
                throw NSError(
                    domain: "Test",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "User fetch failed"]
                )
            }
            
            guard let url = URL(string: "https://jsonplaceholder.typicode.com/users/\(id)") else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(User.self, from: data)
        }
        
        
        
        func fetchPosts(id: Int) async throws -> [Post] {
            if shouldPostsFail {
                throw NSError(
                    domain: "Test",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Posts fetch failed"]
                )
            }
            guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts?userId=\(id)") else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode([Post].self, from: data)
        }
    }
    
    // Test 1: Both succeeds
    let manager1 = UserProfileManagerHandleDifferentErrors(shouldUserFail: false, shouldPostsFail: false)
    await manager1.loadProfile(for: 1)
    
    
    // Test 2: User fails
    let manager2 = UserProfileManagerHandleDifferentErrors(shouldUserFail: true, shouldPostsFail: false)
    await manager2.loadProfile(for: 1)
    
    
    // Test 3: Posts fails
    let manager3 = UserProfileManagerHandleDifferentErrors(shouldUserFail: false, shouldPostsFail: true)
    await manager3.loadProfile(for: 1)
    
    
    // Test 4: Both fails
    let manager4 = UserProfileManagerHandleDifferentErrors(shouldUserFail: true, shouldPostsFail: true)
    await manager4.loadProfile(for: 1)
}


