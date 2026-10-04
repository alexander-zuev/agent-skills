# Visual design

### Typography & markup

Adapted from [Kumo design guidance](https://kumo-ui.com/skill/) for the existing components and tokens.

- Use semantic HTML and centralized typography tokens. App content uses 14px; larger sizes belong to headings.
- Use sentence case for headings and preserve product-name capitalization.
- Use semibold headings and medium inline emphasis. Do not add local `font-bold` or `tracking-*` overrides.
- Size inline code optically through the shared code token, not per-component overrides.
- Keep markup minimal. Use flex/grid `gap-*` for layout spacing.

### Spacing and surfaces

- Keep titles and descriptions closer together than separate content groups.
- Account for line height when balancing padding; vertical padding can be smaller than horizontal padding.
- Align icons with the first text line and match their visual size to the text.
- Keep nearby rounded edges concentric: outer radius equals inner radius plus padding when edges are at most 8px apart.
- For shadowed surfaces, use the shared ring token instead of adding a border. Separate sticky content with a border.

### Interaction and composition

- Apply hover colors immediately; do not animate hover color changes.
- Preserve content dimensions during collapse animations.
- Avoid redundant nested card surfaces; use one card with sections.
- Keep dialog roots mounted and let their `open` state control visibility and exit animations.
- Use existing components and tokens for these rules. Preserve intentional brand and marketing typography.
