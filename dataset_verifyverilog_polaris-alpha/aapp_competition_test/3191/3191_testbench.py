import cocotb
from cocotb.triggers import Timer
import math

def calc_min_time(n_val, r_val, p_val):
    t = [0] * 17  # Precompute up to n=16
    for n in range(2, 17):
        min_cost = None
        for k in range(1, n):
            seg_size = math.ceil(n / (k+1))
            current_cost = p_val * k + r_val + t[seg_size]
            if min_cost is None or current_cost < min_cost:
                min_cost = current_cost
        t[n] = min_cost if min_cost is not None else 0
    return t[n_val] if n_val <= 16 else 0

@cocotb.test()
async def test_crashtime(dut):
    test_cases = [
        (1, 100, 20, 0),
        (10, 10, 1, 19),
        (16, 1, 10, 44)
    ]
    passed = 0
    for (n, r, p, expected) in test_cases:
        dut.n.value = n
        dut.r.value = r
        dut.p.value = p
        await Timer(1, units='ns')
        actual = dut.cost.value
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n} r={r} p={p} -> {actual}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
