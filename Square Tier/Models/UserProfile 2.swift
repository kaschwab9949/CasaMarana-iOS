import Foundation

struct UserProfile: Codable, Equatable {
    var fullName: String
    var phoneE164: String
    var email: String
    var birthday: String

    // Phone verification
    var isPhoneVerified: Bool = false
    var phoneVerificationToken: String? = nil

    static let empty = UserProfile(
        fullName: "",
        phoneE164: "",
        email: "",
        birthday: "",
        isPhoneVerified: false,
        phoneVerificationToken: nil
    )
}
