import type { PieceGroup } from './group';
import { angleDeltaAbs, dist, normalizeAngle, rotateDeg, sub } from './geometry';
import type { Vec2 } from './types';

export interface SnapResult {
  /** Group that absorbed others (the active group itself). */
  survivor: PieceGroup;
  /** Groups that were merged into the survivor (and should be removed). */
  consumed: PieceGroup[];
}

/**
 * Iteratively check whether the active group can snap onto any other group.
 * Snaps may cascade: e.g., snapping piece A snaps the group near piece B simultaneously.
 */
export function trySnap(
  active: PieceGroup,
  others: PieceGroup[],
  positionTolerance: number,
  angleTolerance: number,
): SnapResult {
  const consumed: PieceGroup[] = [];
  let progressed = true;

  while (progressed) {
    progressed = false;
    for (const other of others) {
      if (consumed.includes(other) || other === active) continue;

      if (angleDeltaAbs(active.worldRotation, other.worldRotation) > angleTolerance) continue;

      const match = findNeighborMatch(active, other, positionTolerance);
      if (match) {
        active.worldRotation = normalizeAngle(other.worldRotation);
        active.absorb(other, match.anchorPiece, match.otherPiece);
        // After absorbing, snap position adjustment is implicit because absorb()
        // assigns localOffsets based on neighbor geometry, and the active group's
        // worldPosition is unchanged. The other group's pieces are now drawn relative
        // to active's transform, which lands them at exactly the expected location.
        consumed.push(other);
        progressed = true;
        break; // Re-scan from the top so cascade-snaps can use newly-merged geometry.
      }
    }
  }

  return { survivor: active, consumed };
}

interface NeighborMatch {
  anchorPiece: import('./types').PieceData;
  otherPiece: import('./types').PieceData;
}

function findNeighborMatch(
  a: PieceGroup,
  b: PieceGroup,
  tolerance: number,
): NeighborMatch | null {
  for (const aMember of a.members) {
    for (const neighbor of aMember.piece.neighbors) {
      const bMember = b.members.find((m) => m.piece.id === neighbor.pieceId);
      if (!bMember) continue;

      // Expected world offset from aMember to bMember if they were correctly assembled
      // and the group is at its current rotation.
      const expectedUnrotated: Vec2 = sub(bMember.piece.homePosition, aMember.piece.homePosition);
      const expectedRotated = rotateDeg(expectedUnrotated, a.worldRotation);

      const aWorld = a.pieceWorldCenter(aMember.piece.id)!;
      const bWorld = b.pieceWorldCenter(bMember.piece.id)!;
      const actualDelta: Vec2 = sub(bWorld, aWorld);

      if (dist(expectedRotated, actualDelta) <= tolerance) {
        return { anchorPiece: aMember.piece, otherPiece: bMember.piece };
      }
    }
  }
  return null;
}
