import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_odd_equivalent(dut):
    test_cases = [
        # (input_binary_str, rotation_count, expected_count)
        ("00011001", 6, 3),   # Original "011001" padded to 8b
        ("00011011", 5, 4),   # Original "11011" padded
        ("00001010", 4, 2),   # Original "1010" padded
        ("11111111", 8, 8),   # All 1's case
        ("00000000", 8, 0)    # All 0's case
    ]
    passed = 0
    
    for s_str, n_val, expected in test_cases:
        # Convert binary string to integer
        s_int = int(s_str, 2)
        dut.s.value = s_int
        dut.n.value = n_val
        await Timer(1, units='ns')
        
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: s={s_str} (0x{s_int:02X}) n={n_val} → count={dut.count.value}")
        else:
            dut._log.error(f"FAIL: s={s_str} n={n_val} → {dut.count.value} (expected {expected})")
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed}/{total} tests"