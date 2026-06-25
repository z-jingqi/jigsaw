import Phaser from "phaser";
import { forwardRef, useEffect, useImperativeHandle, useRef } from "react";
import { GameMode, LevelRecord } from "../data/types";
import { PuzzleScene } from "./scenes/PuzzleScene";

export interface PhaserHostHandle {
  showHint: () => void;
}

interface PhaserHostProps {
  level: LevelRecord;
  mode: GameMode;
  onComplete: () => void;
}

export const PhaserHost = forwardRef<PhaserHostHandle, PhaserHostProps>(function PhaserHost({ level, mode, onComplete }, ref) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const gameRef = useRef<Phaser.Game | null>(null);
  const sceneRef = useRef<PuzzleScene | null>(null);

  useImperativeHandle(ref, () => ({
    showHint() {
      sceneRef.current?.showHint();
    },
  }));

  useEffect(() => {
    const parent = containerRef.current;
    if (!parent) return;

    const scene = new PuzzleScene({ level, mode, onComplete });
    sceneRef.current = scene;
    const game = new Phaser.Game({
      type: Phaser.AUTO,
      parent,
      width: Math.max(1, parent.clientWidth),
      height: Math.max(1, parent.clientHeight),
      backgroundColor: level.backgroundColor,
      scene,
      scale: {
        mode: Phaser.Scale.RESIZE,
        autoCenter: Phaser.Scale.NO_CENTER,
      },
      render: {
        antialias: true,
        pixelArt: false,
      },
    });
    gameRef.current = game;

    return () => {
      sceneRef.current = null;
      gameRef.current?.destroy(true);
      gameRef.current = null;
    };
  }, [level, mode, onComplete]);

  return <div className="phaser-host" ref={containerRef} />;
});
