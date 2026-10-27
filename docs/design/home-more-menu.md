# Home More menu

The menu is a local warm-paper panel without a pointer notch. Its 48-native-pixel rows use original vector grid, artwork and gear icons, left-aligned 16-pixel labels, and no background at rest. Hover is very light gray; pressing adds one inset gray background. Keyboard focus adds one thin outline, including while pressed. These styles do not change Clean.button or other screens.

Pointer/touch opening does not grab or paint row focus. Keyboard activation focuses the first visible item; Tab/Shift-Tab and up/down navigate only visible rows. The first reverse Tab selects the last visible item. Input owned or quarantined by GestureArena is rejected before changing input modality. Escape/Back and outside dismissal preserve the prior input-consumption contract; pointer dismissal does not restore a stale keyboard frame.

Album availability continues to follow discovered pictures, updates even while the menu is open, and removes the row and its focus target when none remain. Labels refresh on opening for locale changes. Long labels remain single-line with ellipsis and retain their full accessibility name.

Verification: normal desktop Godot windows at 430x900 and 320x568, Chinese/English/Japanese, all three actions, default/pressed/focus/pressed-plus-focus, repeated outside dismissal without card activation, dynamic album availability, hidden-row focus traversal, keyboard-to-pointer transition, held page gesture rejecting a secondary finger and keyboard input. External native InputEvents were injected; touch opening includes an explicit platform-compatible mouse click because Viewport.push_input does not synthesize that event. This is not a physical-phone claim. Repository automated suites remain paused.
