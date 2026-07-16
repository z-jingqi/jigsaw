import * as React from "react";

type NavigationAction = () => void;

type PendingNavigation = {
  action: NavigationAction;
  discard?: NavigationAction;
};

export function useUnsavedChangesGuard() {
  const [hasUnsavedChanges, setHasUnsavedChanges] = React.useState(false);
  const [pendingNavigation, setPendingNavigation] = React.useState<PendingNavigation | null>(null);

  React.useEffect(() => {
    if (!hasUnsavedChanges) return;

    function handleBeforeUnload(event: BeforeUnloadEvent) {
      event.preventDefault();
      event.returnValue = "";
    }

    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, [hasUnsavedChanges]);

  const requestNavigation = React.useCallback((action: NavigationAction, discard?: NavigationAction) => {
    if (!hasUnsavedChanges) {
      action();
      return;
    }
    setPendingNavigation({ action, discard });
  }, [hasUnsavedChanges]);

  const cancelNavigation = React.useCallback(() => {
    setPendingNavigation(null);
  }, []);

  const discardAndContinue = React.useCallback(() => {
    const pending = pendingNavigation;
    setPendingNavigation(null);
    setHasUnsavedChanges(false);
    pending?.discard?.();
    pending?.action();
  }, [pendingNavigation]);

  return {
    confirmationOpen: pendingNavigation !== null,
    setHasUnsavedChanges,
    requestNavigation,
    cancelNavigation,
    discardAndContinue,
  };
}
