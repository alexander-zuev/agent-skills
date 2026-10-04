# Phone surfaces

These rules apply to phone products, PWAs, and phone flows. Desktop and mixed surfaces do not inherit them.
Use the `web-design-guidelines` skill when auditing these surfaces.

- Use `FieldDescription` for field help. Do not hide required help behind hover.
- Use Tooltip when the pointer supports hover and Popover on tap. Reuse the project's `HoverOrTap` when available.
- Use a bottom `Sheet` for long copy or action groups.
- Give icon-only controls a visible word or `aria-label`.
- Use `svh` or `dvh` for frame height.

When connection drops during a flow, show an alert and disable the action.
A status word is sufficient on a list. Do not ban Tooltip; handle touch explicitly.
