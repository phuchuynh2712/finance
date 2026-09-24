# Contract: Shared Widget

## Example contract: dashed border primitives

The shared dashed-border widget may expose only presentation inputs:

```text
child: Widget
color: Color
strokeWidth: double
dashWidth: double
gapWidth: double
borderRadius: double (rounded rectangle only)
```

The top-border variant must render the same dashed horizontal line currently used by both feature areas. The rounded-rectangle variant must preserve its existing radius and stroke behavior where it remains in use.

## Rules

- The widget must not import a feature domain model, repository, provider, router, or feature-local localization key.
- The widget must not perform data access, validation, allocation, balance calculation, or navigation.
- Consumers own labels, localized strings, theme selection, and callbacks.
- Defaults must preserve the current behavior unless a deliberate compatibility change is documented.
- The widget must be tested for construction, configurable visual inputs, and consumer integration where the painter affects layout or separators.
- A visually similar feature widget is not a consumer unless its behavior and state contract are equivalent.

## Reuse decision

Move a widget to `core/widgets` only when at least two feature areas use the same contract. Keep semantically different group cards, item rows, and account fields local; use explicit composition or small visual slots only when a future contract is demonstrated.
