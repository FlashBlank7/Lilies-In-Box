#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

EXPECTED_LEVELS = [
    ("P-1 先学会看见", "See -> Push"),
    ("P-2 记忆的重量", "See -> Remember -> Push"),
    ("P-3 回声门", "Remember -> See -> Push"),
]

EXPECTED_WORKFLOW_TASKS = [
    "1-1 会害怕的门",
    "1-2 低声花",
    "1-3 不确定的台阶",
    "1-4 疑问的影子",
]

REQUIRED_ACTIONS = [
    "move_left",
    "move_right",
    "jump",
    "interact",
    "toggle_builder",
    "deploy_friend",
    "restart_chapter",
]

REQUIRED_SFX = [
    "pickup_chime.wav",
    "drawer_tick.wav",
    "block_place.wav",
    "soft_error.wav",
    "friend_wake.wav",
    "door_open.wav",
    "chapter_complete.wav",
]

RESOURCE_RE = re.compile(r'(?:preload|load)\("res://([^"\n]+)"\)')
RISKY_VARIANT_RE = re.compile(
    r"var\s+\w+\s*:=.*("
    r"get_meta|pop_back|get_children|get_child|get_node|call\(|\[[^\]]+\]"
    r")"
)


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def require_file(path: Path, failures: list[str]) -> str:
    if not path.exists():
        fail(f"missing file: {rel(path)}", failures)
        return ""
    return read_text(path)


def check_project_config(failures: list[str]) -> None:
    project = require_file(ROOT / "project.godot", failures)
    if 'run/main_scene="res://scenes/Main.tscn"' not in project:
        fail("project.godot must run res://scenes/Main.tscn", failures)
    for action in REQUIRED_ACTIONS:
        if f"{action}={{" not in project:
            fail(f"missing input action: {action}", failures)


def check_scene_entrypoints(failures: list[str]) -> None:
    main_scene = require_file(ROOT / "scenes/Main.tscn", failures)
    room_scene = require_file(ROOT / "scenes/Room01.tscn", failures)
    room_02_scene = require_file(ROOT / "scenes/Room02.tscn", failures)
    chapter_01_scene = require_file(ROOT / "scenes/Chapter01Workflow.tscn", failures)
    main_script = require_file(ROOT / "scripts/main.gd", failures)
    if "res://scripts/main.gd" not in main_scene:
        fail("Main.tscn must use scripts/main.gd", failures)
    if "res://scripts/room_puzzle.gd" not in room_scene:
        fail("Room01.tscn must use scripts/room_puzzle.gd", failures)
    if "res://scripts/room02_platform.gd" not in room_02_scene:
        fail("Room02.tscn must use scripts/room02_platform.gd", failures)
    if "res://scripts/chapter01_workflow.gd" not in chapter_01_scene:
        fail("Chapter01Workflow.tscn must use scripts/chapter01_workflow.gd", failures)
    if 'preload("res://scenes/Room01.tscn")' not in main_script:
        fail("main.gd must preload Room01.tscn", failures)
    if 'preload("res://scenes/Room02.tscn")' not in main_script:
        fail("main.gd must preload Room02.tscn", failures)
    if 'preload("res://scenes/Chapter01Workflow.tscn")' not in main_script:
        fail("main.gd must preload Chapter01Workflow.tscn", failures)
    if "func _build_start_screen() -> void:" not in main_script:
        fail("main.gd must build the start screen", failures)
    if "func _on_chapter_one_completed() -> void:" not in main_script:
        fail("main.gd must transition from Prologue rooms to Echo Steps", failures)
    required_main_tokens = [
        "var awaiting_end_restart := false",
        "func _on_level_two_completed() -> void:",
        "func _on_workflow_chapter_completed() -> void:",
        "func _build_end_screen() -> void:",
        "func _return_to_title() -> void:",
        'current_scene.connect("level_completed", Callable(self, "_on_level_two_completed"))',
        'current_scene.connect("chapter_completed", Callable(self, "_on_workflow_chapter_completed"))',
        'title.text = "Demo 完成"',
    ]
    for token in required_main_tokens:
        if token not in main_script:
            fail(f"missing main ending token: {token}", failures)


def check_scripts_compile_shape(failures: list[str]) -> None:
    for script in sorted((ROOT / "scripts").glob("*.gd")):
        text = read_text(script)
        opens = text.count("(") + text.count("[") + text.count("{")
        closes = text.count(")") + text.count("]") + text.count("}")
        if opens != closes:
            fail(f"bracket mismatch in {rel(script)}: {opens - closes}", failures)
        for line_number, line in enumerate(text.splitlines(), 1):
            if line.startswith("    "):
                fail(f"space indentation in {rel(script)}:{line_number}", failures)
        for match in RESOURCE_RE.finditer(text):
            target = ROOT / match.group(1)
            if not target.exists():
                fail(f"missing resource {match.group(1)} referenced by {rel(script)}", failures)
        for match in RISKY_VARIANT_RE.finditer(text):
            line_number = text[: match.start()].count("\n") + 1
            fail(f"risky Variant inference in {rel(script)}:{line_number}", failures)


def check_chapter_contract(failures: list[str]) -> None:
    room = require_file(ROOT / "scripts/room_puzzle.gd", failures)
    room2 = require_file(ROOT / "scripts/room02_platform.gd", failures)
    chapter1 = require_file(ROOT / "scripts/chapter01_workflow.gd", failures)
    evaluator = require_file(ROOT / "scripts/workflow_evaluator.gd", failures)
    target = require_file(ROOT / "scripts/encounter_target.gd", failures)
    result = require_file(ROOT / "scripts/workflow_result.gd", failures)
    builder = require_file(ROOT / "scripts/friend_builder.gd", failures)
    friend = require_file(ROOT / "scripts/friend_actor.gd", failures)
    inventory = require_file(ROOT / "scripts/block_inventory.gd", failures)
    readme = require_file(ROOT / "README.md", failures)
    concept = require_file(ROOT / "docs/concept.md", failures)
    smoke = require_file(ROOT / "tools/chapter_smoke_test.gd", failures)

    if "const CHAPTER_LEVEL_COUNT := 3" not in room:
        fail("Prologue must have exactly 3 tutorial rooms in room_puzzle.gd", failures)

    sequence_patterns = [
        r"else:\s*required\.append\(\"See\"\)\s*required\.append\(\"Push\"\)",
        r"if chapter_level_index == 1:\s*required\.append\(\"See\"\)\s*required\.append\(\"Remember\"\)\s*required\.append\(\"Push\"\)",
        r"elif chapter_level_index == 2:\s*required\.append\(\"Remember\"\)\s*required\.append\(\"See\"\)\s*required\.append\(\"Push\"\)",
    ]
    for pattern in sequence_patterns:
        if not re.search(pattern, room):
            fail(f"missing level sequence pattern: {pattern}", failures)

    for title, sequence in EXPECTED_LEVELS:
        if title not in room:
            fail(f"missing level title in room script: {title}", failures)
        if f"{title}`" not in readme and title not in readme:
            fail(f"missing level title in README: {title}", failures)
        if title not in concept:
            fail(f"missing level title in concept doc: {title}", failures)
        if sequence not in readme:
            fail(f"missing sequence in README: {sequence}", failures)
        if sequence not in concept:
            fail(f"missing sequence in concept doc: {sequence}", failures)

    required_room_tokens = [
        "builder.set_goal_hint(_level_name(), _level_required_text())",
        "func _show_room_banner() -> void:",
        "func _show_chapter_complete_banner() -> void:",
        "chapter_banner.text = \"Prologue",
        "var progress_label: Label",
        "func _update_progress_label() -> void:",
        "func _inventory_text() -> String:",
        "progress_label.text = \"门 %d/%d",
        "progress_label.text = \"Prologue 完成",
        "if room_complete or chapter_complete:",
        "get_viewport().set_input_as_handled()",
        'event.is_action_pressed("restart_chapter")',
        "func _restart_chapter() -> void:",
        "var transition_in_progress := false",
        "transition_in_progress = true",
        "transition_in_progress = false",
        "inventory.clear()",
        "friend.cancel()",
        "func friend_recall() -> String:",
        "func friend_push_box(actor: Node2D) -> void:",
        "player.can_finish = true",
    ]
    for token in required_room_tokens:
        if token not in room:
            fail(f"missing room behavior token: {token}", failures)

    if room.count("builder.set_goal_hint(_level_name(), _level_required_text())") < 2:
        fail("builder goal hint should be set on startup and on level load", failures)

    for filename in REQUIRED_SFX:
        if not (ROOT / "assets/audio/sfx" / filename).exists():
            fail(f"missing local SFX asset: assets/audio/sfx/{filename}", failures)
        if not (ROOT / "assets/audio/sfx" / f"{filename}.import").exists():
            fail(f"missing Godot import metadata for SFX: assets/audio/sfx/{filename}.import", failures)

    required_sfx_tokens = [
        "const SFX_PICKUP :=",
        "const SFX_DRAWER :=",
        "const SFX_BLOCK :=",
        "const SFX_ERROR :=",
        "const SFX_FRIEND :=",
        "const SFX_DOOR :=",
        "const SFX_CHAPTER :=",
        "func _make_sfx_player(node_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:",
        "builder.feedback_requested.connect(_play_feedback)",
        'func _play_feedback(kind: String) -> void:',
        '_play_feedback("pickup")',
        '_play_feedback("friend")',
        '_play_feedback("door")',
        '_play_feedback("chapter")',
    ]
    for token in required_sfx_tokens:
        if token not in room:
            fail(f"missing SFX room token: {token}", failures)

    required_builder_tokens = [
        "signal feedback_requested(kind: String)",
        'const BLOCK_ORDER: Array[String] = ["See", "Listen", "Remember", "Compare", "Hold", "Push", "Quiet"]',
        "func set_goal_hint(new_room_title: String, new_goal_text: String) -> void:",
        "func set_workflow_feedback(summary: String, trace: Array[String]) -> void:",
        "func clear_workflow_feedback() -> void:",
        "room_title",
        "goal_text",
        "workflow_summary_label",
        "trace_label",
        'feedback_requested.emit("drawer")',
        'feedback_requested.emit("block")',
        'feedback_requested.emit("error")',
    ]
    for token in required_builder_tokens:
        if token not in builder:
            fail(f"missing builder behavior token: {token}", failures)
    if "第一扇门需要 See -> Push" in builder or "把 See 放在前面" in builder:
        fail("builder still contains stale hard-coded first-room hint", failures)
    if 'func _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed("toggle_builder"):' not in builder:
        fail("builder toggle handler has unexpected indentation", failures)
    if '\n\thint_label.text = "按 1-7 选择已拥有的节点' not in builder:
        fail("builder hint refresh has unexpected indentation", failures)

    required_friend_tokens = [
        "var run_token := 0",
        "func cancel() -> void:",
        'room.has_method("run_friend_workflow")',
        "_run_sequence(run_token)",
        "func _run_sequence(token: int) -> void:",
        "if token != run_token:",
        'room.has_method("friend_recall")',
        'room.has_method("friend_push_box")',
        'remembered_fact != "box_to_button"',
    ]
    for token in required_friend_tokens:
        if token not in friend:
            fail(f"missing friend behavior token: {token}", failures)

    if "func clear() -> void:" not in inventory or "blocks.clear()" not in inventory:
        fail("inventory must support clearing for chapter restart", failures)

    required_workflow_tokens = [
        "class_name EncounterTarget",
        "var required_evidence: Array[String]",
        "class_name WorkflowResult",
        "func summary() -> String:",
        "class_name WorkflowEvaluator",
        "static func evaluate(sequence: Array[String], target: EncounterTarget) -> WorkflowResult:",
        "TERMINAL_ACTIONS",
        "缺少证据",
        "风险太高",
        "signal chapter_completed",
        "const CHAPTER_TASK_COUNT := 4",
        "func run_friend_workflow(actor: Node2D, sequence: Array[String]) -> bool:",
        "builder.set_workflow_feedback(result.summary(), result.trace)",
        "WorkflowEvaluator.evaluate(sequence, target)",
    ]
    workflow_blob = "\n".join([target, result, evaluator, chapter1])
    for token in required_workflow_tokens:
        if token not in workflow_blob:
            fail(f"missing workflow feedback token: {token}", failures)

    for title in EXPECTED_WORKFLOW_TASKS:
        if title not in chapter1:
            fail(f"missing workflow task in Chapter 1 script: {title}", failures)
        if title not in readme:
            fail(f"missing workflow task in README: {title}", failures)
        if title not in concept:
            fail(f"missing workflow task in concept doc: {title}", failures)

    required_room2_tokens = [
        "signal level_completed",
        "const PETAL_COUNT := 3",
        "func _add_platforms() -> void:",
        "func _create_petal(label_text: String, pos: Vector2) -> void:",
        "func _add_echo_petal_visual(visual: Node2D) -> void:",
        "func _add_petal_leaf(visual: Node2D, points: PackedVector2Array, color: Color, z: int) -> void:",
        "visual.name = \"EchoPetalVisual\"",
        "var outer_halo := Polygon2D.new()",
        "func _try_collect_petal() -> void:",
        "func _open_door() -> void:",
        "func _finish_level() -> void:",
        "func _respawn_player() -> void:",
        "player.jump_velocity = -410.0",
        "petals_collected >= PETAL_COUNT",
    ]
    for token in required_room2_tokens:
        if token not in room2:
            fail(f"missing Level 2 token: {token}", failures)
    if "const FLOWERS_TEXTURE" in room2 or "flower.texture" in room2:
        fail("Level 2 echo petals should not reuse the flower spritesheet crop", failures)

    required_smoke_tokens = [
        'const MAIN_SCENE := preload("res://scenes/Main.tscn")',
        'const ROOM_SCENE := preload("res://scenes/Room01.tscn")',
        'const ROOM_02_SCENE := preload("res://scenes/Room02.tscn")',
        'const CHAPTER_01_SCENE := preload("res://scenes/Chapter01Workflow.tscn")',
        "await _test_main_start_screen()",
        "_test_workflow_evaluator()",
        "func _test_main_start_screen() -> void:",
        'await main.call("_on_chapter_one_completed")',
        'await main.call("_on_level_two_completed")',
        'await main.call("_on_workflow_chapter_completed")',
        'main waits on ending after Chapter 1',
        "func _test_chapter_01_workflow() -> void:",
        'await _solve_workflow_task(["See", "Compare", "Push"], 0, true)',
        'await _solve_workflow_task(["See", "Listen", "Quiet"], 1, true)',
        'await _solve_workflow_task(["Remember", "See", "Hold", "Push"], 2, true)',
        'await _solve_workflow_task(["Listen", "Remember", "Compare", "Quiet"], 3, false)',
        'await _solve_level(["See", "Push"], 0, true)',
        'await _solve_level(["See", "Remember", "Push"], 1, true)',
        'await _solve_level(["Remember", "See", "Push"], 2, false)',
        'await room.call("_restart_chapter")',
        "await _test_room_02()",
        "func _collect_room_02_petal(pos: Vector2) -> void:",
        'print("Chapter smoke test passed.")',
    ]
    for token in required_smoke_tokens:
        if token not in smoke:
            fail(f"missing smoke test token: {token}", failures)

    required_readme_tokens = [
        "python3 tools/verify_chapter.py",
        "--headless --path . --import",
        "--headless --path . --script tools/chapter_smoke_test.gd",
        "Prologue：回声台阶",
        "Chapter 1：寂静的概率花园",
        "WorkflowEvaluator",
        "开始界面",
    ]
    for token in required_readme_tokens:
        if token not in readme:
            fail(f"missing README verification command: {token}", failures)


def main() -> int:
    failures: list[str] = []
    check_project_config(failures)
    check_scene_entrypoints(failures)
    check_scripts_compile_shape(failures)
    check_chapter_contract(failures)

    if failures:
        print("Chapter verification FAILED:")
        for item in failures:
            print(f"- {item}")
        return 1

    print("Chapter verification passed.")
    print("Checked: scene entrypoint, input actions, resources, scripts, Prologue, and workflow Chapter 1 contract.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
