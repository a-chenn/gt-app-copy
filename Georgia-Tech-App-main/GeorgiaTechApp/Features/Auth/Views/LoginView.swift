//
//  LoginView.swift
//  GeorgiaTechApp
//

import SwiftUI

struct LoginView: View {
    @State private var loginVM = LoginVM()

    var body: some View {
        ZStack {
            LinearGradient.gtNavyGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                brandMark

                Spacer()

                VStack(spacing: 14) {
                    if let error = loginVM.errorMessage {
                        Text(error)
                            .font(.gtBody3)
                            // NOT gtGold: it measures 2.83:1 against the
                            // sweep's gtBrightBlue stop, below even the
                            // 3:1 large-text floor, and this is footnote
                            // size. Light Gold clears 4.5 on both stops
                            // (4.73 bright blue / 9.38 navy).
                            .foregroundStyle(Color.gtLightGold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        loginVM.startGTSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.shield.checkmark")
                            Text("Sign in with GT SSO")
                        }
                        .font(.gtHeading4)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.gtNavy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient.gtGoldGradient, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the Georgia Tech single sign-on page")

                    Button {
                        loginVM.signInAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .font(.gtHeading6)
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .foregroundStyle(Color.gtWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .overlay {
                                Capsule().strokeBorder(Color.gtWhite.opacity(0.4), lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Uses the app without a GT account")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .disabled(loginVM.isSigningIn)

                if loginVM.isSigningIn {
                    ProgressView()
                        .tint(Color.gtGold)
                        .padding(.bottom, 24)
                }

                Text("Designed and Developed by iOS Club")
                    .font(.gtBody3).italic()
                    .foregroundStyle(Color.gtWhite.opacity(0.6))
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var brandMark: some View {
        VStack(spacing: 22) {
            // Official vertical lockup, pinned to its reversed cut for
            // the navy sweep behind it.
            GTLockup(style: .vertical, height: 150, onDark: true)
                .shadow(color: Color.gtNavy.opacity(0.4), radius: 16, y: 8)

            Text("The Official Campus App")
                .font(.gtHeading6)
                .textCase(.uppercase)
                .tracking(2.6)
                .foregroundStyle(Color.gtBuzz)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Georgia Tech, the official campus app")
    }
}

#Preview {
    LoginView()
}
