//
//  ContentView.swift
//  Moment
//
//  Root view with navigation based on app state
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    
    var body: some View {
        Group {
            if viewModel.isCheckingAuth {
                LoadingView()
            } else {
                switch viewModel.currentScreen {
                case .loading:
                    LoadingView()
                    
                case .auth:
                    AuthView(viewModel: viewModel)
                    
                case .onboarding:
                    OnboardingView(viewModel: viewModel)
                    
                case .setupCycle:
                    SetupCycleView(viewModel: viewModel)
                    
                case .home:
                    HomeView(viewModel: viewModel)
                }
            }
        }
        .animation(.momentEase, value: viewModel.currentScreen)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.momentBackground
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.momentGreen.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isAnimating ? 1.2 : 1)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.momentGreen)
                }
                
                Text("Moment")
                    .font(.momentHeadline)
                    .foregroundColor(.momentCharcoal)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ContentView()
}
