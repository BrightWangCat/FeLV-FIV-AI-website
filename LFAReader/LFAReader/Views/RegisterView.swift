import SwiftUI

struct RegisterView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    private var formValid: Bool {
        !username.isEmpty && !email.isEmpty && !password.isEmpty && passwordsMatch
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)

                        Text("Create Account")
                            .font(.title.bold())
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    // Form fields
                    VStack(spacing: 16) {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)

                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Register button
                    Button {
                        Task {
                            await authViewModel.register(
                                username: username,
                                email: email,
                                password: password
                            )
                            if authViewModel.isAuthenticated {
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!formValid || authViewModel.isLoading)
                    .padding(.horizontal)

                    // Back to login
                    Button {
                        dismiss()
                    } label: {
                        Text("Already have an account? **Sign In**")
                            .font(.callout)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RegisterView()
        .environment(AuthViewModel())
}
