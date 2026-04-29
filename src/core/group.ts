import type { PieceData, Vec2 } from './types';
import { add, rotateDeg, sub } from './geometry';

export interface GroupMember {
  piece: PieceData;
  /** Offset of this piece's home center from the group anchor's home center, in unrotated source-space. */
  localOffset: Vec2;
}

let nextGroupId = 0;

export class PieceGroup {
  readonly id: number;
  members: GroupMember[];
  /** World position of the group anchor (the first member's home center) in canvas coords. */
  worldPosition: Vec2;
  /** Multiple of 90 in [0, 360). */
  worldRotation: number;

  constructor(piece: PieceData, worldPosition: Vec2, worldRotation: number) {
    this.id = nextGroupId++;
    this.members = [{ piece, localOffset: [0, 0] }];
    this.worldPosition = worldPosition;
    this.worldRotation = worldRotation;
  }

  /** World coordinates of the home-center of a member piece given the group's transform. */
  pieceWorldCenter(pieceId: string): Vec2 | null {
    const member = this.members.find((m) => m.piece.id === pieceId);
    if (!member) return null;
    const rotated = rotateDeg(member.localOffset, this.worldRotation);
    return add(this.worldPosition, rotated);
  }

  hasPiece(pieceId: string): boolean {
    return this.members.some((m) => m.piece.id === pieceId);
  }

  /** Absorb other group's members into this one, snapping their world positions to align. */
  absorb(other: PieceGroup, anchorPiece: PieceData, otherPiece: PieceData): void {
    // Compute the localOffset (in unrotated source-space) for each piece of the other group,
    // such that otherPiece lands exactly where its neighbor relationship to anchorPiece dictates.
    // Expected unrotated offset of otherPiece relative to anchor:
    const expectedOffsetUnrotated = sub(otherPiece.homePosition, anchorPiece.homePosition);
    const anchorMember = this.members.find((m) => m.piece.id === anchorPiece.id)!;
    const otherAnchorOffset = add(anchorMember.localOffset, expectedOffsetUnrotated);

    // For every member in `other`, compute its new localOffset in this group's frame.
    // In `other`, otherPiece had localOffset = other.members.find(otherPiece).localOffset.
    const otherPieceMember = other.members.find((m) => m.piece.id === otherPiece.id)!;
    const otherFrameToThisFrame = sub(otherAnchorOffset, otherPieceMember.localOffset);

    for (const m of other.members) {
      this.members.push({
        piece: m.piece,
        localOffset: add(m.localOffset, otherFrameToThisFrame),
      });
    }
  }
}

export function resetGroupIds(): void {
  nextGroupId = 0;
}
