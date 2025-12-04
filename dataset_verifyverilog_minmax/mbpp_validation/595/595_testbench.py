import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_swaps(dut):
    test_cases = [
        # Original test cases padded to 4 bits
        ("1101", "1110", 1, 0),
        ("0111", "0000", 3, 1),  # Original "111","000"
        ("0111", "0110", 1, 1),   # Original "111","110"
        # Additional cases
        ("0000", "0000", 0, 0),   # No swaps needed
        ("0101", "1010", 4, 0)    # 2 swaps required
    ]
    passed = 0
    for s1, s2, expect_count, expect_err in test_cases:
        dut.str1.value = int(s1, 2)
        dut.str2.value = int(s2, 2)
        await Timer(1, units='ns')
        if dut.error.value == expect_err:
            if expect_err or dut.swap_count.value == expect_count:
                passed += 1
                dut._log.info(f"PASS: {s1}->{s2}: got {dut.swap_count.value} (err={dut.error.value})")
            else:
                dut._log.error(f"FAIL: {s1}->{s2}: count got {dut.swap_count.value} vs {expect_count}")
        else:
            dut._log.error(f"FAIL: {s1}->{s2}: error {dut.error.value} vs {expect_err}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")