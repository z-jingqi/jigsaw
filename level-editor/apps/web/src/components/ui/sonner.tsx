import { Toaster as Sonner, type ToasterProps } from "sonner";

export function Toaster(props: ToasterProps) {
  return (
    <Sonner
      position="top-center"
      duration={3000}
      closeButton
      toastOptions={{
        classNames: {
          toast: "border border-stone-300 bg-[#2b1d15] text-white shadow-xl",
          description: "text-white/80",
          actionButton: "bg-clay text-white",
          cancelButton: "bg-white/10 text-white",
        },
      }}
      {...props}
    />
  );
}
