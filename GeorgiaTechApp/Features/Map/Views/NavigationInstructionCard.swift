//
//  NavigationInstructionCard.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The turn-by-turn card floating over the top of the map during
/// navigation (Figma "Navigation"): the upcoming maneuver large, the one
/// after it faded beneath, and a grabber that expands the card into the
/// full remaining step list ending at the destination address.
struct NavigationInstructionCard: View {
    @Environment(RouteManager.self) private var routeManager
    @State private var isExpanded = false

    private var upcomingSteps: [NavigationStep] {
        routeManager.navigationSteps
            .filter { $0.id >= routeManager.displayedStepIndex && !$0.instructions.isEmpty }
    }

    var body: some View {
        let steps = upcomingSteps
        if let current = steps.first {
            VStack(spacing: 0) {
                Button(action: toggle) {
                    stepRow(
                        current,
                        distance: routeManager.distanceToNextManeuver ?? current.distance,
                        isPrimary: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Hides the remaining steps" : "Shows every remaining step")

                if isExpanded {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(steps.dropFirst()) { step in
                                stepRow(step, distance: step.distance, isPrimary: true)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                    .background(Color.gtOverlay2)
                } else if let next = steps.dropFirst().first {
                    HStack(spacing: 14) {
                        Image(systemName: next.icon)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 36)
                        Text(next.streetName ?? next.actionText)
                            .font(.gtBody2)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.gtSecondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.gtOverlay2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Then \(next.instructions)")
                }

                Button(action: toggle) {
                    Capsule()
                        .fill(Color.gtGray2)
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse steps" : "Show all steps")
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.gtOverlay1, radius: 8, y: 2)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onEnded { value in
                    if value.translation.height > 20, !isExpanded { toggle() }
                    if value.translation.height < -20, isExpanded { toggle() }
                }
            )
        } else if routeManager.hasArrived {
            arrivedCard
        }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isExpanded.toggle()
        }
    }

    private func stepRow(_ step: NavigationStep, distance: Double, isPrimary: Bool) -> some View {
        let isArrival = step.icon == "mappin.circle.fill"
        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: isArrival ? "mappin" : step.icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.gtPrimaryText)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(RouteNavigation.maneuverDistanceText(distance))
                    .font(.gtHeading2)
                    .foregroundStyle(Color.gtPrimaryText)
                Text(isArrival
                     ? (routeManager.stops.last?.name ?? step.instructions)
                     : (step.streetName ?? step.actionText))
                    .font(.gtBody1)
                    .foregroundStyle(Color.gtSecondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("In \(RouteNavigation.maneuverDistanceText(distance)), \(step.instructions)")
    }

    private var arrivedCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.gtTechLawn)
            VStack(alignment: .leading, spacing: 2) {
                Text("You've arrived")
                    .font(.gtHeading2)
                    .foregroundStyle(Color.gtPrimaryText)
                if let destination = routeManager.stops.last?.name {
                    Text(destination)
                        .font(.gtBody1)
                        .foregroundStyle(Color.gtSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.gtOverlay1, radius: 8, y: 2)
        .accessibilityElement(children: .combine)
    }
}
