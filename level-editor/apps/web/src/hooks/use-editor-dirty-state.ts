import * as React from "react";

export function useEditorDirtyState(onDirtyChange: (dirty: boolean) => void, hasChanges: boolean) {
  React.useEffect(() => {
    onDirtyChange(hasChanges);
  }, [hasChanges, onDirtyChange]);

  React.useEffect(() => () => {
    onDirtyChange(false);
  }, [onDirtyChange]);
}
