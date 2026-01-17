//
//  SetupCycleView.swift
//  Moment
//
//  Initial cycle setup for new users
//

import SwiftUI

/*
 SCREEN: Setup Cycle
 PURPOSE: First cycle entry after woman onboarding
 COPY EXAMPLE:
 
 Title: "Let's set up your cycle"
 Subtitle: "When did your last period start?"
 Note: "Don't worry if you're not sure — we'll learn as we go"
 CTA: "Start Tracking"
*/

struct SetupCycleView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedDate = Date()
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.momentBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Illustration
                ZStack {
                    Circle()
                        .fill(Color.momentRose.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.05 : 1)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.momentRose)
                }
                .padding(.bottom, Spacing.xl)
                
                Text("Let's set up your cycle")
                    .font(.momentDisplaySmall)
                    .foregroundColor(.momentCharcoal)
                    .padding(.bottom, Spacing.xs)
                
                Text("When did your last period start?")
                    .font(.momentBody)
                    .foregroundColor(.momentSecondaryText)
                    .padding(.bottom, Spacing.lg)
                
                // Date picker
                DatePicker(
                    "Period start",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.momentRose)
                .environment(\.colorScheme, .light)
                .padding(.horizontal, Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.white)
                        .padding(.horizontal, Spacing.md)
                )
                .momentShadowSubtle()
                .padding(.horizontal, Spacing.md)
                
                Spacer()
                
                VStack(spacing: Spacing.md) {
                    Text("Don't worry if you're not sure —\nwe'll learn as we go")
                        .font(.momentCaption)
                        .foregroundColor(.momentSecondaryText)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Tracking") {
                        viewModel.startNewCycle(startDate: selectedDate)
                    }
                    .buttonStyle(MomentPrimaryButtonStyle())
                    
                    Text("Moment is not a medical device and does not provide medical advice.")
                        .font(.system(size: 11))
                        .foregroundColor(.momentWarmGray)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SetupCycleView(viewModel: AppViewModel())
}
