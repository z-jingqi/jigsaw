import type { PythonTool } from "../../types";
import { fetchJson } from "./client";

export function fetchPythonTools() {
  return fetchJson<{ ok?: boolean; tools?: PythonTool[] }>("/api/python-tools");
}
