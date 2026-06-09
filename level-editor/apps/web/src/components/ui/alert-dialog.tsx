import type * as React from "react";
import * as AlertDialogPrimitive from "@radix-ui/react-alert-dialog";
import { cn } from "../../lib/utils";
import { buttonVariants } from "./button";

const AlertDialog = AlertDialogPrimitive.Root;
const AlertDialogTrigger = AlertDialogPrimitive.Trigger;
const AlertDialogPortal = AlertDialogPrimitive.Portal;
const AlertDialogOverlay = ({ className, ...props }: AlertDialogPrimitive.AlertDialogOverlayProps) => (
  <AlertDialogPrimitive.Overlay className={cn("fixed inset-0 z-50 bg-black/80", className)} {...props} />
);
const AlertDialogContent = ({ className, ...props }: AlertDialogPrimitive.AlertDialogContentProps) => (
  <AlertDialogPortal>
    <AlertDialogOverlay />
    <AlertDialogPrimitive.Content
      className={cn(
        "fixed left-1/2 top-1/2 z-50 grid w-full max-w-lg -translate-x-1/2 -translate-y-1/2 gap-4 border bg-background p-6 shadow-lg sm:rounded-lg",
        className,
      )}
      {...props}
    />
  </AlertDialogPortal>
);
const AlertDialogHeader = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col space-y-2 text-center sm:text-left", className)} {...props} />
);
const AlertDialogFooter = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", className)} {...props} />
);
const AlertDialogTitle = AlertDialogPrimitive.Title;
const AlertDialogDescription = AlertDialogPrimitive.Description;
const AlertDialogAction = ({ className, ...props }: AlertDialogPrimitive.AlertDialogActionProps) => (
  <AlertDialogPrimitive.Action className={cn(buttonVariants(), className)} {...props} />
);
const AlertDialogCancel = ({ className, ...props }: AlertDialogPrimitive.AlertDialogCancelProps) => (
  <AlertDialogPrimitive.Cancel
    className={cn("mt-2 inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground sm:mt-0", className)}
    {...props}
  />
);

export {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
};
