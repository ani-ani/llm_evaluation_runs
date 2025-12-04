import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_toggle(dut):
    test_cases = [
        (9, 15),
        (10, 12),
        (11, 13),
        (0b1000001, 0b1111111),  # 65 → 127
        (0b1001101, 0b1110011)   # 77 → 115
    ]
    passed = 0
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(10, units='ns')
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {n_val} → {result}")
        else:
            dut._log.error(f"FAIL: {n_val} → {result}, expected {expected}")
    # Edge cases
    for edge_case in [0, 1, 255]:
        dut.n.value = edge_case
        await Timer(10, units='ns')
        if edge_case in [0,1]:
            expected = edge_case
        else:  # 255 case (all bits set)
            expected = (0b10000001)  # preserves first/last bit
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {edge_case} → {result}")
        else:
            dut._log.error(f"FAIL: {edge_case} → {result}, expected {expected}")
    total = len(test_cases) + 3  # original tests + edge cases
    dut._log.info(f"{passed}/{total} tests passed")