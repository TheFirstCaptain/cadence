# Cadence Design Guidelines

## Design intent

Cadence should feel calm, clear, supportive, and occasionally playful. It is a companion for finding a sustainable rhythm, not a system that grades the user.

## Principles

1. **Consistency over perfection.** Show patterns and progress without treating a missed action as failure.
2. **Awareness without judgment.** Occasional indulgence is a normal part of life. Use neutral language that helps the user notice frequency and patterns without labeling an individual choice as bad.
3. **Planning without rigidity.** Make weekly intentions easy to revise as life changes.
4. **Tracking without effort.** Prefer one-tap completion and very short logging flows.

## Visual direction

- Use muted greens, soft blues, and warm neutrals.
- Favor clean SwiftUI typography and generous spacing.
- Use simple progress rings, bars, or a subtle rhythm/wave motif.
- Use simple monochrome Apple-style symbols for iIndulged categories; pair every symbol with text and an accessibility label.
- Keep animation gentle and purposeful.
- Maintain strong contrast and support Dynamic Type and VoiceOver.

## Tone and language

- Be warm, brief, and encouraging.
- Describe what happened without moralizing it.
- Prefer phrases such as “Keep your rhythm” and “There’s always tomorrow.”
- Avoid angry red warnings, broken-streak messaging, shame, and excessive gamification.

## Navigation

Keep the primary structure small and predictable:

- **My Day:** Today's Goals first, followed by fast iIndulged occurrence logging.
- **My Goals:** Weekly intention-setting and Goal management.
- **History:** Simple review of past plans, checkoffs, and indulgences.

V1 uses exactly these three primary tabs. Settings may be added later only when genuine app preferences exist.

## Interaction standards

- Daily checkoff: one tap.
- Common indulgence occurrence: one tap on the category's plus control.
- Accidental occurrence correction: one tap on the category's minus control.
- Use quiet selection or light haptics for checkoffs and counters, immediate visual state changes, and concise VoiceOver announcements.
- Do not use routine sounds, banners, confetti, or confirmation dialogs for reversible everyday actions.
- Respect Reduce Motion by removing nonessential count and checkmark animation.
- Important actions should be reachable with one hand.
- Always provide clear empty states and reversible editing where possible.
