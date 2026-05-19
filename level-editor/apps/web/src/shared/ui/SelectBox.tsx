import * as Select from "@radix-ui/react-select";
import { Check, ChevronDown } from "lucide-react";

export type SelectOption = {
  value: string;
  label: string;
  detail?: string;
};

export function SelectBox({ value, options, placeholder, onValueChange }: { value: string; options: SelectOption[]; placeholder: string; onValueChange: (value: string) => void }) {
  return (
    <Select.Root value={value} onValueChange={onValueChange}>
      <Select.Trigger className="selectTrigger" aria-label={placeholder}>
        <Select.Value placeholder={placeholder} />
        <Select.Icon>
          <ChevronDown size={16} />
        </Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content className="selectContent" position="popper" sideOffset={6}>
          <Select.Viewport className="p-1">
            {options.map((option) => (
              <Select.Item key={option.value} value={option.value} className="selectItem">
                <Select.ItemText>
                  <span>{option.label}</span>
                  {option.detail && <small>{option.detail}</small>}
                </Select.ItemText>
                <Select.ItemIndicator>
                  <Check size={14} />
                </Select.ItemIndicator>
              </Select.Item>
            ))}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  );
}
