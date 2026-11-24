import { describe, expect, it } from "vitest";
import { planSlugForAmount } from "@/lib/billing/infinitepay-rules";

const plans = [
  { slug: "free", preco_cents: 0 },
  { slug: "starter", preco_cents: 1490 },
  { slug: "pro", preco_cents: 2500 },
];
describe("valor pago → plano", () => {
  it("R$ 14,90 ativa Basic", () => expect(planSlugForAmount(1490, plans)).toBe("starter"));
  it("R$ 25,00 ativa PRO", () => expect(planSlugForAmount(2500, plans)).toBe("pro"));
  it("valor zero nunca ativa o Gratuito", () => expect(planSlugForAmount(0, plans)).toBeNull());
});
