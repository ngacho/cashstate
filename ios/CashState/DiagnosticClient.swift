import Combine
import ConvexMobile
import ClerkKit

struct UserLookupResult: Decodable {
    let found: Bool
    let email: String?
}

/// No-auth Convex client used to isolate whether the user row exists in the DB
/// independently of JWT auth. Call checkUserExists() to run the isolation test.
final class DiagnosticClient {
    static let shared = DiagnosticClient()
    private let client = ConvexClient(deploymentUrl: Config.convexURL)

    private init() {}

    func checkUserExists() async {
        guard let clerkId = await Clerk.shared.user?.id else {
            print("🔍 [Diagnostic] No Clerk user available")
            return
        }
        print("🔍 [Diagnostic] Looking up clerkId: \(clerkId)")
        do {
            let result: UserLookupResult = try await withCheckedThrowingContinuation { cont in
                var cancellable: AnyCancellable?
                cancellable = client
                    .subscribe(to: "users:getByClerkId", with: ["clerkId": clerkId], yielding: UserLookupResult.self)
                    .first()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                cont.resume(throwing: error)
                            }
                            cancellable?.cancel()
                        },
                        receiveValue: { value in
                            cont.resume(returning: value)
                        }
                    )
            }
            if result.found {
                print("🔍 [Diagnostic] User EXISTS in DB — email: \(result.email ?? "nil") — auth issue is CLERK_JWT_ISSUER_DOMAIN mismatch")
            } else {
                print("🔍 [Diagnostic] User NOT FOUND in DB for clerkId \(clerkId) — webhook may not have fired")
            }
        } catch {
            print("🔍 [Diagnostic] Query failed: \(error)")
        }
    }
}
