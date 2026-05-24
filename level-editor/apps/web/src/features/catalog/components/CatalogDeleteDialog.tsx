import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "../../../components/ui/alert-dialog";

type Content = { title: string; description: string } | null;

type Props = {
  content: Content;
  onCancel: () => void;
  onConfirm: () => void;
};

export function CatalogDeleteDialog({ content, onCancel, onConfirm }: Props) {
  return (
    <AlertDialog
      open={Boolean(content)}
      onOpenChange={(open: boolean) => {
        if (!open) onCancel();
      }}
    >
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{content?.title}</AlertDialogTitle>
          <AlertDialogDescription>{content?.description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>取消</AlertDialogCancel>
          <AlertDialogAction className="bg-[#9e3f35] hover:bg-[#87342c]" onClick={onConfirm}>
            删除
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
