# Level Editor Gamepad Support

## Goal

Provide a controller-friendly editing workflow for the level editor without breaking the current mouse-first workflow.

## Constraints From Current Project

- The editor is a `Control`-based screen built in `scenes/editor/editor_scene.gd`.
- The board canvas is a `Node2D` in `scenes/editor/editor_board.gd`.
- Gameplay actions already go through `InputManager` and GUIDE.
- UI navigation already uses Godot `ui_*` actions and gamepad bindings.
- Playtest intentionally disables editor UI input while active.

## Recommended Approach

Add a dedicated editor cursor and editor-specific gamepad actions rather than trying to reuse gameplay movement directly.

## Proposed Editor States

1. UI Focus Mode
- Default when entering the editor.
- D-pad / left stick navigates buttons and panels.
- `A` confirms focused button.
- `B` cancels dialogs or leaves subpanels.

2. Board Edit Mode
- Entered by pressing `X` while the board host is focused.
- A visible cursor appears on the board.
- Most controller editing happens here.

3. Board Pan Mode
- Hold `LB` to pan the board with left stick.
- While held, editing actions are suspended.

## Proposed Input Mapping

Add a small editor-only action set:

- `editor_cursor_up`
- `editor_cursor_down`
- `editor_cursor_left`
- `editor_cursor_right`
- `editor_paint`
- `editor_erase`
- `editor_cycle_tool_prev`
- `editor_cycle_tool_next`
- `editor_cycle_color_prev`
- `editor_cycle_color_next`
- `editor_cycle_shape`
- `editor_pan_modifier`
- `editor_toggle_board_mode`

Suggested default gamepad bindings:

- Left stick / D-pad: move board cursor
- `A`: apply current tool to hovered cell
- `B`: erase current cell or exit board mode
- `X`: toggle between UI focus mode and board edit mode
- `Y`: cycle shape
- `LB` / `RB`: previous / next tool
- `LT` / `RT`: previous / next color
- Hold `LB` + left stick: pan board
- `Back`: undo
- `Start`: test play

## Board Edit Mode Behavior

### Cursor

- Add an editor cursor cell independent of mouse hover.
- If the player was using mouse last, hide gamepad cursor until board mode is entered.
- When entering board mode, place cursor at:
  - current mouse cell if valid, else
  - player start, else
  - board center.

### Editing

- `A` applies current tool to cursor cell.
- Holding `A` while moving cursor paints continuously for `SINGLE` shape.
- `B` erases current cell.
- For `RECT` and `LINE`:
  - first `A` stores anchor
  - moving cursor updates preview
  - second `A` commits shape.

### Auto Camera / Auto Pan

- Reuse the board pan offset already implemented for mouse.
- If cursor approaches the visible edge, auto-pan enough to keep it visible.
- Manual pan via `editor_pan_modifier` should override auto-pan for that frame.

## UI Integration

- Keep Godot focus navigation for toolbar and side panels.
- Add one explicit focusable control above the board host, e.g. `Board Focus` button or invisible focus proxy.
- Pressing `X` from that focus proxy enters board mode.
- Exiting board mode returns focus to that proxy so gamepad users do not get lost.

## Minimal Implementation Plan

1. Add editor-specific actions to `InputManager` or a small editor-local input layer.
2. Add board cursor state to `editor_board.gd`.
3. Draw cursor highlight distinct from mouse hover.
4. Implement board mode enter/exit in `editor_scene.gd`.
5. Implement single-cell paint/erase with controller.
6. Reuse `_pan_offset` and pan clamp logic for controller pan and auto-pan.
7. Add tool/color/shape cycling shortcuts.
8. Add a short on-screen help label for controller mode.

## Why This Approach

- Fits the existing split between UI navigation and board editing.
- Avoids fighting Godot's built-in focus system.
- Reuses current board rendering and pan logic.
- Keeps playtest isolation intact.
- Can be shipped incrementally instead of as a risky full rewrite.

## Recommended First Milestone

Implement only:

- board mode toggle
- board cursor movement
- `A` paint
- `B` erase
- `LB` / `RB` cycle tool
- hold modifier to pan

That provides a usable first controller editing pass with low implementation risk.
