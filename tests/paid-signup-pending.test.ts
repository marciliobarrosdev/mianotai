import { describe, it, expect } from "vitest";
import { companyNeedsPayment } from "@/lib/billing/plan-transition-rules";

describe("cadastro com plano pago", () => {
  it("conta aguardando pagamento fica presa no checkout", () => {
    expect(companyNeedsPayment({ status_cobranca: "checkout_pending", trial_ate: null })).toBe(true);
  });
  it("conta ativa após pagamento libera o app", () => {
    expect(companyNeedsPayment({ status_cobranca: "ativo", trial_ate: null })).toBe(false);
  });
});
