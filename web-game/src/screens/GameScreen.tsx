import { useCallback, useRef, useState } from "react";
import { GameMode, LevelRecord } from "../data/types";
import { PhaserHost, PhaserHostHandle } from "../game/PhaserHost";
import { CompleteDialog } from "./CompleteDialog";

interface GameScreenProps {
  level: LevelRecord;
  mode: GameMode;
  onBack: () => void;
  onComplete: () => void;
}

export function GameScreen({ level, mode, onBack, onComplete }: GameScreenProps) {
  const hostRef = useRef<PhaserHostHandle | null>(null);
  const [completed, setCompleted] = useState(false);
  const handleComplete = useCallback(() => {
    setCompleted(true);
  }, []);

  return (
    <section className="game-screen">
      <header className="game-hud">
        <button className="plain-icon-button" type="button" onClick={onBack} aria-label="返回">
          <img src="/assets/icons/phosphor/caret-left.svg" alt="" />
        </button>
        <h1>{level.title}</h1>
        <div className="game-hud__actions">
          {mode !== "swap" ? (
            <button className="plain-icon-button game-hint-button" type="button" onClick={() => hostRef.current?.showHint()} aria-label="提示">
              <img src="/assets/icons/phosphor/lightbulb.svg" alt="" />
            </button>
          ) : null}
        </div>
      </header>
      <PhaserHost
        ref={hostRef}
        level={level}
        mode={mode}
        onComplete={handleComplete}
      />
      {completed ? (
        <CompleteDialog
          imageUrl={level.imageUrl}
          title={level.title}
          onConfirm={() => {
            setCompleted(false);
            onComplete();
          }}
        />
      ) : null}
    </section>
  );
}
