/**
 * Reputation — a worker's computed trust and quality score.
 * Built from appreciation patterns over time.
 */

export interface ReputationPublic {
  score: number;          // 0-100
  consistency: number;    // 0-1
  frequency: number;      // 0-1
  uniqueTippers: number;  // count
}
