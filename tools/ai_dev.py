#!/usr/bin/env python3
"""Reproducible local development entry point for Godot + AI workflows."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_ROOT = ROOT / ".artifacts" / "ai-dev"
PLUGIN_CONFIG = ROOT / "addons" / "godot_ai" / "plugin.cfg"
PLUGIN_PROVENANCE = ROOT / "addons" / "godot_ai" / "UPSTREAM.md"
PROJECT_CONFIG = ROOT / "project.godot"
EXPECTED_PLUGIN_VERSION = "3.0.5"
EXPECTED_PLUGIN_COMMIT = "2313b6441ae605ee6cf49dd69f74cab30231da39"
EXPECTED_ARCHIVE_SHA256 = "fa3fc45849e9aa652d6689612252de1f251f8a34ad5dfc7cbb72d94a9845ee05"
DEFAULT_MCP_PORT = 8000

VERSION_RE = re.compile(r"(?P<major>\d+)\.(?P<minor>\d+)(?:\.(?P<patch>\d+))?")


def _utc_run_id() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")


def _new_artifact_dir() -> Path:
    path = ARTIFACT_ROOT / _utc_run_id()
    (path / "logs").mkdir(parents=True, exist_ok=False)
    return path


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, default=str) + "\n", encoding="utf-8")


def _emit_result(payload: Dict[str, Any], exit_code: int) -> int:
    payload["exit_code"] = exit_code
    print("JIGSAW_AI_RESULT " + json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str))
    return exit_code


def _godot_binary() -> Optional[Path]:
    configured = os.environ.get("GODOT_BIN", "").strip()
    candidates: List[Optional[str]] = [
        configured or None,
        "/Applications/Godot.app/Contents/MacOS/Godot" if sys.platform == "darwin" else None,
        shutil.which("godot"),
        shutil.which("godot4"),
        shutil.which("Godot.exe") if os.name == "nt" else None,
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate).resolve()
    return None


def _command_version(command: Sequence[str]) -> Dict[str, Any]:
    try:
        completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=8, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "error": str(exc)}
    output = (completed.stdout or completed.stderr).strip()
    return {"ok": completed.returncode == 0, "value": output, "exit_code": completed.returncode}


def _version_at_least(value: str, minimum: Tuple[int, int, int]) -> bool:
    match = VERSION_RE.search(value)
    if not match:
        return False
    actual = (
        int(match.group("major")),
        int(match.group("minor")),
        int(match.group("patch") or 0),
    )
    return actual >= minimum


def _plugin_version() -> str:
    if not PLUGIN_CONFIG.is_file():
        return ""
    match = re.search(r'^version\s*=\s*"([^"]+)"', PLUGIN_CONFIG.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1) if match else ""


def _plugin_enabled() -> bool:
    if not PROJECT_CONFIG.is_file():
        return False
    text = PROJECT_CONFIG.read_text(encoding="utf-8")
    return "[editor_plugins]" in text and 'res://addons/godot_ai/plugin.cfg' in text


def _provenance_ok() -> bool:
    if not PLUGIN_PROVENANCE.is_file():
        return False
    text = PLUGIN_PROVENANCE.read_text(encoding="utf-8")
    return EXPECTED_PLUGIN_COMMIT in text and EXPECTED_ARCHIVE_SHA256 in text


def _editor_setting_files() -> Iterable[Path]:
    candidates: List[Path] = []
    if sys.platform == "darwin":
        candidates.extend((Path.home() / "Library" / "Application Support" / "Godot").glob("editor_settings-*.tres"))
    candidates.extend((Path.home() / ".config" / "godot").glob("editor_settings-*.tres"))
    if os.name == "nt" and os.environ.get("APPDATA"):
        candidates.extend((Path(os.environ["APPDATA"]) / "Godot").glob("editor_settings-*.tres"))
    return sorted(set(candidates), reverse=True)


def _editor_network_settings() -> Dict[str, Any]:
    http_port = DEFAULT_MCP_PORT
    allow_remote_hosts = ""
    sources: List[str] = []
    for path in _editor_setting_files():
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        port_match = re.search(r'godot_ai/http_port\s*=\s*(\d+)', text)
        hosts_match = re.search(r'godot_ai/allow_remote_hosts\s*=\s*"([^"]*)"', text)
        if port_match:
            http_port = int(port_match.group(1))
            sources.append(str(path))
        if hosts_match:
            allow_remote_hosts = hosts_match.group(1).strip()
            sources.append(str(path))
        if port_match or hosts_match:
            break
    return {
        "http_port": http_port,
        "allow_remote_hosts": allow_remote_hosts,
        "loopback_only": not allow_remote_hosts,
        "source": sources[0] if sources else "plugin_defaults",
    }


def _tcp_listening(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.6):
            return True
    except OSError:
        return False


def _status_probe(port: int) -> Dict[str, Any]:
    url = f"http://127.0.0.1:{port}/godot-ai/status"
    request = urllib.request.Request(url, headers={"Accept": "application/json"}, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=1.5) as response:
            body = response.read().decode("utf-8", errors="replace")
            parsed = json.loads(body)
            return {"ok": response.status == 200 and isinstance(parsed, dict), "url": url, "status": response.status, "data": parsed}
    except urllib.error.HTTPError as exc:
        return {"ok": False, "url": url, "status": exc.code, "error": str(exc)}
    except (OSError, ValueError) as exc:
        return {"ok": False, "url": url, "status": 0, "error": str(exc)}


def _parse_mcp_response(body: str) -> Dict[str, Any]:
    stripped = body.strip()
    if not stripped:
        return {}
    if stripped.startswith("{"):
        parsed = json.loads(stripped)
        return parsed if isinstance(parsed, dict) else {}
    messages: List[Dict[str, Any]] = []
    for line in stripped.splitlines():
        if not line.startswith("data:"):
            continue
        value = line[5:].strip()
        if not value:
            continue
        parsed = json.loads(value)
        if isinstance(parsed, dict):
            messages.append(parsed)
    return messages[-1] if messages else {}


def _mcp_post(port: int, payload: Dict[str, Any], session_id: str = "") -> Tuple[Dict[str, Any], str]:
    headers = {
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json",
    }
    if session_id:
        headers["Mcp-Session-Id"] = session_id
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/mcp",
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=3.0) as response:
        body = response.read().decode("utf-8", errors="replace")
        next_session_id = response.headers.get("Mcp-Session-Id", session_id)
        return _parse_mcp_response(body), next_session_id


def _resource_text(response: Dict[str, Any]) -> Any:
    result = response.get("result", {})
    contents = result.get("contents", []) if isinstance(result, dict) else []
    for item in contents:
        if not isinstance(item, dict) or not isinstance(item.get("text"), str):
            continue
        try:
            return json.loads(item["text"])
        except ValueError:
            return item["text"]
    return None


def _flatten_dicts(value: Any) -> Iterable[Dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for nested in value.values():
            yield from _flatten_dicts(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from _flatten_dicts(nested)


def _mcp_session_probe(port: int) -> Dict[str, Any]:
    try:
        initialize, session_id = _mcp_post(
            port,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-03-26",
                    "capabilities": {},
                    "clientInfo": {"name": "jigsaw-ai-doctor", "version": "1.0"},
                },
            },
        )
        if "result" not in initialize:
            return {"ok": False, "error": initialize.get("error", "initialize_failed")}
        try:
            _mcp_post(port, {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}, session_id)
        except (urllib.error.HTTPError, OSError, ValueError):
            pass
        response, _ = _mcp_post(
            port,
            {"jsonrpc": "2.0", "id": 2, "method": "resources/read", "params": {"uri": "godot://sessions"}},
            session_id,
        )
        sessions = _resource_text(response)
        project_root = str(ROOT.resolve())
        matches: List[Dict[str, Any]] = []
        for item in _flatten_dicts(sessions):
            candidate_paths = [str(item.get(key, "")) for key in ("project_path", "path", "project")]
            if any(value and str(Path(value).expanduser().resolve()) == project_root for value in candidate_paths):
                matches.append(item)
        return {
            "ok": "result" in response,
            "current_project_connected": bool(matches),
            "matching_sessions": matches,
            "sessions": sessions,
            "error": response.get("error", ""),
        }
    except (urllib.error.HTTPError, OSError, ValueError, json.JSONDecodeError) as exc:
        return {"ok": False, "current_project_connected": False, "error": str(exc)}


def _codex_config_check(port: int) -> Dict[str, Any]:
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()
    path = codex_home / "config.toml"
    if not path.is_file():
        return {"ok": False, "path": str(path), "error": "config_missing"}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return {"ok": False, "path": str(path), "error": str(exc)}
    section = re.search(
        r'(?ms)^\[mcp_servers\.(?:"godot-ai"|godot-ai|godot_ai)\]\s*(.*?)(?=^\[|\Z)',
        text,
    )
    if not section:
        return {"ok": False, "path": str(path), "error": "section_missing"}
    body = section.group(1)
    expected_url = f"http://127.0.0.1:{port}/mcp"
    url_match = re.search(r'^url\s*=\s*"([^"]+)"', body, re.MULTILINE)
    enabled_match = re.search(r'^enabled\s*=\s*(true|false)', body, re.MULTILINE | re.IGNORECASE)
    actual_url = url_match.group(1) if url_match else ""
    enabled = enabled_match is None or enabled_match.group(1).lower() == "true"
    return {
        "ok": actual_url == expected_url and enabled,
        "path": str(path),
        "url": actual_url,
        "expected_url": expected_url,
        "enabled": enabled,
    }


def _base_manifest(run_dir: Path, operation: str, started_at: Optional[str] = None) -> Dict[str, Any]:
    return {
        "schema_version": 1,
        "run_id": run_dir.name,
        "operation": operation,
        "started_at": started_at or dt.datetime.now(dt.timezone.utc).isoformat(),
        "project": str(ROOT),
        "platform": {"system": platform.system(), "release": platform.release(), "machine": platform.machine()},
        "plugin_version": _plugin_version(),
        "artifacts": {
            "root": str(run_dir),
            "manifest": str(run_dir / "manifest.json"),
            "editor_log": str(run_dir / "logs" / "editor.json"),
            "game_log": str(run_dir / "logs" / "game.json"),
            "screenshots": str(run_dir / "screenshots"),
        },
    }


def command_doctor(_: argparse.Namespace) -> int:
    run_dir = _new_artifact_dir()
    started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    started = time.monotonic()
    godot = _godot_binary()
    godot_version = _command_version([str(godot), "--version"]) if godot else {"ok": False, "error": "not_found"}
    uv = shutil.which("uv")
    uv_version = _command_version([uv, "--version"]) if uv else {"ok": False, "error": "not_found"}
    network = _editor_network_settings()
    port = int(network["http_port"])
    tcp_listening = _tcp_listening(port)
    status = _status_probe(port)
    status_data = status.get("data", {}) if isinstance(status.get("data"), dict) else {}
    recognized = bool(status.get("ok")) and str(status_data.get("name", "")).lower().replace("_", "-") == "godot-ai"
    sessions = _mcp_session_probe(port) if recognized else {"ok": False, "current_project_connected": False, "error": "server_offline"}
    codex_config = _codex_config_check(port)
    checks = {
        "godot": {
            "ok": bool(godot) and bool(godot_version.get("ok")) and _version_at_least(str(godot_version.get("value", "")), (4, 6, 0)),
            "path": str(godot) if godot else "",
            "version": godot_version,
            "minimum": "4.6.0",
        },
        "uv": {"ok": bool(uv) and bool(uv_version.get("ok")), "path": uv or "", "version": uv_version},
        "plugin": {
            "ok": _plugin_version() == EXPECTED_PLUGIN_VERSION and _plugin_enabled() and _provenance_ok(),
            "version": _plugin_version(),
            "expected_version": EXPECTED_PLUGIN_VERSION,
            "enabled": _plugin_enabled(),
            "provenance": _provenance_ok(),
        },
        "network": {
            "ok": network["loopback_only"] and port == DEFAULT_MCP_PORT,
            **network,
            "tcp_listening": tcp_listening,
            "foreign_listener": tcp_listening and not recognized,
        },
        "mcp": {"ok": recognized, "status": status, "sessions": sessions},
        "codex_config": codex_config,
    }
    core_ok = all(bool(checks[name]["ok"]) for name in ("godot", "uv", "plugin", "network"))
    bridge_ok = recognized and bool(sessions.get("current_project_connected")) and bool(codex_config.get("ok"))
    actions: List[str] = []
    if not checks["godot"]["ok"]:
        actions.append("Install Godot 4.6+ or set GODOT_BIN to the editor executable.")
    if not checks["uv"]["ok"]:
        actions.append("Install uv; doctor never installs dependencies automatically.")
    if not checks["plugin"]["ok"]:
        actions.append("Restore the vendored Godot AI v3.0.5 subtree and enable it in project.godot.")
    if not checks["network"]["ok"]:
        actions.append("Clear godot_ai/allow_remote_hosts and set godot_ai/http_port to 8000 in Godot Editor Settings.")
    if checks["network"]["foreign_listener"]:
        actions.append(f"Port {port} is occupied by a non-Godot-AI process; identify it manually. No process was terminated.")
    elif not recognized:
        actions.append("Open this project with `python3 tools/ai_dev.py open` and wait for the Godot AI dock to turn green.")
    if not codex_config.get("ok"):
        actions.append(f"Configure Codex MCP at {codex_config.get('path')} with URL http://127.0.0.1:{port}/mcp, then restart Codex.")
    elif recognized and not sessions.get("current_project_connected"):
        actions.append("Activate the jigsaw editor session after confirming its project path in session_list.")
    exit_code = 0 if core_ok and bridge_ok else (2 if not core_ok else 3)
    manifest = _base_manifest(run_dir, "doctor", started_at)
    manifest.update(
        {
            "ok": exit_code == 0,
            "core_ok": core_ok,
            "editor_bridge_ok": bridge_ok,
            "checks": checks,
            "actions": actions,
            "duration_seconds": round(time.monotonic() - started, 3),
            "exit_code": exit_code,
        }
    )
    _write_json(run_dir / "logs" / "editor.json", {"status": status, "sessions": sessions})
    _write_json(run_dir / "logs" / "game.json", {"tests": []})
    _write_json(run_dir / "manifest.json", manifest)
    return _emit_result(
        {
            "ok": exit_code == 0,
            "operation": "doctor",
            "core_ok": core_ok,
            "editor_bridge_ok": bridge_ok,
            "checks": checks,
            "actions": actions,
            "artifact_dir": str(run_dir),
        },
        exit_code,
    )


def command_open(_: argparse.Namespace) -> int:
    run_dir = _new_artifact_dir()
    started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    started = time.monotonic()
    godot = _godot_binary()
    uv = shutil.which("uv")
    errors: List[str] = []
    if not godot:
        errors.append("Godot executable not found; set GODOT_BIN.")
    if not uv:
        errors.append("uv not found; install it before opening the AI-enabled editor.")
    if _plugin_version() != EXPECTED_PLUGIN_VERSION or not _plugin_enabled():
        errors.append("Vendored Godot AI v3.0.5 is missing or disabled.")
    if errors:
        exit_code = 2
        manifest = _base_manifest(run_dir, "open", started_at)
        manifest.update(
            {
                "ok": False,
                "errors": errors,
                "duration_seconds": round(time.monotonic() - started, 3),
                "exit_code": exit_code,
            }
        )
        _write_json(run_dir / "logs" / "editor.json", {"errors": errors})
        _write_json(run_dir / "logs" / "game.json", {"tests": []})
        _write_json(run_dir / "manifest.json", manifest)
        return _emit_result({"ok": False, "operation": "open", "errors": errors, "artifact_dir": str(run_dir)}, exit_code)
    env = os.environ.copy()
    env["GODOT_AI_DISABLE_TELEMETRY"] = "true"
    process_log = run_dir / "logs" / "editor-process.log"
    try:
        with process_log.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(
                [str(godot), "--editor", "--path", str(ROOT)],
                cwd=ROOT,
                env=env,
                stdout=output,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            time.sleep(2.0)
            early_exit = process.poll()
    except OSError as exc:
        exit_code = 2
        errors.append(str(exc))
        pid = None
    else:
        pid = process.pid
        if early_exit is None:
            exit_code = 0
        else:
            exit_code = 2
            errors.append(f"Godot editor exited early with code {early_exit}; see {process_log}.")
    manifest = _base_manifest(run_dir, "open", started_at)
    manifest.update(
        {
            "ok": exit_code == 0,
            "pid": pid,
            "process_log": str(process_log),
            "telemetry_disabled": True,
            "errors": errors,
            "duration_seconds": round(time.monotonic() - started, 3),
            "exit_code": exit_code,
        }
    )
    _write_json(
        run_dir / "logs" / "editor.json",
        {"pid": pid, "process_log": str(process_log), "telemetry_disabled": True, "errors": errors},
    )
    _write_json(run_dir / "logs" / "game.json", {"tests": []})
    _write_json(run_dir / "manifest.json", manifest)
    return _emit_result(
        {
            "ok": exit_code == 0,
            "operation": "open",
            "pid": pid,
            "process_log": str(process_log),
            "telemetry_disabled": True,
            "errors": errors,
            "artifact_dir": str(run_dir),
        },
        exit_code,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Godot AI development helper for Jigsaw")
    subparsers = parser.add_subparsers(dest="command", required=True)
    doctor = subparsers.add_parser("doctor", help="Check the pinned editor bridge and local toolchain")
    doctor.set_defaults(handler=command_doctor)
    open_parser = subparsers.add_parser("open", help="Open the normal Godot editor with telemetry disabled")
    open_parser.set_defaults(handler=command_open)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    try:
        return int(args.handler(args))
    except KeyboardInterrupt:
        return _emit_result({"ok": False, "operation": args.command, "error": "interrupted"}, 130)
    except Exception as exc:  # Defensive: preserve the one-line machine contract.
        return _emit_result({"ok": False, "operation": args.command, "error": f"{type(exc).__name__}: {exc}"}, 70)


if __name__ == "__main__":
    raise SystemExit(main())
