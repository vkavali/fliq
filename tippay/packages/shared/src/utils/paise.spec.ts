import {
  rupeesToPaise,
  paiseToRupees,
  formatPaise,
  calculateCommission,
  calculateGstOnCommission,
} from './paise';
import {
  ZERO_COMMISSION_THRESHOLD_PAISE,
  DEFAULT_COMMISSION_RATE,
  GST_RATE_ON_COMMISSION,
} from '../constants/commission';

describe('Paise Utilities', () => {
  describe('rupeesToPaise', () => {
    it('converts whole rupees to paise', () => {
      expect(rupeesToPaise(100)).toBe(10000);
    });

    it('converts decimal rupees to paise', () => {
      expect(rupeesToPaise(99.5)).toBe(9950);
    });

    it('handles zero', () => {
      expect(rupeesToPaise(0)).toBe(0);
    });
  });

  describe('paiseToRupees', () => {
    it('converts paise to rupees', () => {
      expect(paiseToRupees(10000)).toBe(100);
    });

    it('handles fractional rupees', () => {
      expect(paiseToRupees(9950)).toBe(99.5);
    });
  });

  describe('formatPaise', () => {
    it('formats paise as INR string', () => {
      expect(formatPaise(10000)).toBe('₹100.00');
    });

    it('formats fractional amounts', () => {
      expect(formatPaise(9950)).toBe('₹99.50');
    });
  });

  describe('calculateCommission', () => {
    it('returns 0 for tips at or below threshold', () => {
      expect(calculateCommission(5000, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE)).toBe(0);
      expect(calculateCommission(10000, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE)).toBe(0);
    });

    it('returns 5% for tips above threshold', () => {
      // Rs 200 = 20000 paise → 5% = 1000 paise
      expect(calculateCommission(20000, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE)).toBe(1000);
    });

    it('returns correct commission for large amounts', () => {
      // Rs 1000 = 100000 paise → 5% = 5000 paise
      expect(calculateCommission(100000, ZERO_COMMISSION_THRESHOLD_PAISE, DEFAULT_COMMISSION_RATE)).toBe(5000);
    });
  });

  describe('calculateGstOnCommission', () => {
    it('returns 18% GST on commission', () => {
      // 1000 paise commission → 18% = 180 paise
      expect(calculateGstOnCommission(1000, GST_RATE_ON_COMMISSION)).toBe(180);
    });

    it('returns 0 for 0 commission', () => {
      expect(calculateGstOnCommission(0, GST_RATE_ON_COMMISSION)).toBe(0);
    });

    it('rounds down to nearest paise', () => {
      // 333 * 0.18 = 59.94 → should floor to 59
      expect(calculateGstOnCommission(333, GST_RATE_ON_COMMISSION)).toBe(59);
    });
  });
});
