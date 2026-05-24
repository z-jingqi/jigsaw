import { useCallback, useState } from "react";
import { cloneSnapshot } from "../lib/editor";
import type { EditorSnapshot } from "../types";

const HISTORY_LIMIT = 50;

export type EditorHistory = {
  canUndo: boolean;
  canRedo: boolean;
  pushUndo: (snapshot: EditorSnapshot) => void;
  reset: () => void;
  undo: (current: EditorSnapshot) => EditorSnapshot | null;
  redo: (current: EditorSnapshot) => EditorSnapshot | null;
};

export function useEditorHistory(): EditorHistory {
  const [undoStack, setUndoStack] = useState<EditorSnapshot[]>([]);
  const [redoStack, setRedoStack] = useState<EditorSnapshot[]>([]);

  const pushUndo = useCallback((snapshot: EditorSnapshot) => {
    setUndoStack((current) => [...current.slice(-(HISTORY_LIMIT - 1)), cloneSnapshot(snapshot)]);
    setRedoStack([]);
  }, []);

  const reset = useCallback(() => {
    setUndoStack([]);
    setRedoStack([]);
  }, []);

  const undo = useCallback(
    (current: EditorSnapshot): EditorSnapshot | null => {
      if (!undoStack.length) return null;
      const previous = undoStack[undoStack.length - 1];
      setUndoStack(undoStack.slice(0, -1));
      setRedoStack([...redoStack, cloneSnapshot(current)]);
      return previous;
    },
    [redoStack, undoStack],
  );

  const redo = useCallback(
    (current: EditorSnapshot): EditorSnapshot | null => {
      if (!redoStack.length) return null;
      const next = redoStack[redoStack.length - 1];
      setRedoStack(redoStack.slice(0, -1));
      setUndoStack([...undoStack, cloneSnapshot(current)]);
      return next;
    },
    [redoStack, undoStack],
  );

  return {
    canUndo: undoStack.length > 0,
    canRedo: redoStack.length > 0,
    pushUndo,
    reset,
    undo,
    redo,
  };
}
