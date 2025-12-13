import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_interval(dut):
    test_cases = [
        # (a_start, a_end, b_start, b_end), expected
        ((1, 2, 2, 3), "NO"),  # No intersection
        ((-1, 1, 0, 4), "NO"),  # Intersection len=1
        ((-3, -1, -5, 5), "YES"),  # Len=2 (prime)
        ((-2, 2, -4, 0), "YES"),  # Len=2 (prime)
        ((-11, 2, -1, -1), "NO"), # Single point
        ((1, 2, 3, 5), "NO"),    # No intersection
        ((1, 2, 1, 2), "NO"),    # Len=1
        ((-2, -2, -3, -2), "NO"),# Single point
        # Additional edge cases
        ((5, 10, 7, 8), "YES"),  # Len=3 (prime)
        ((0, 4, 0, 6), "NO")     # Len=4 (non-prime)
    ]
    passed = 0
    for i, ((a_s, a_e, b_s, b_e), exp) in enumerate(test_cases):
        dut.a_start.value = a_s
        dut.a_end.value = a_e
        dut.b_start.value = b_s
        dut.b_end.value = b_e
        await Timer(1, units='ns')
        actual = "YES" if dut.prime_found.value == 1 else "NO"
        if actual == exp:
            passed += 1
            dut._log.info(f"TEST {i}: PASS
 Input: ({a_s},{a_e}), ({b_s},{b_e})
 Output: {actual}")
        else:
            dut._log.error(f"TEST {i}: FAIL
 Input: ({a_s},{a_e}), ({b_s},{b_e})
 Expected: {exp}, Got: {actual}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")