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
}


