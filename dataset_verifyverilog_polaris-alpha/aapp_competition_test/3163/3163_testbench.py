import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_min_lifts(dut):
    test_cases = [
        # Test1: Valid arrangement (1 mismatch => 1 lift)
        ((1,0, 3,4, 1,0, 3,4), 0),
        # Test2: Swapped books (2 mismatches)
        ((1,2, 0,3, 2,1, 3,0), 2),
        # Test3: Impossible (different book sets)
        ((1,2, 3,4, 5,6, 7,8), -1)
    ]

    passed = 0
    for (c0p0, c0p1, c1p0, c1p1, t0p0, t0p1, t1p0, t1p1), expected in test_cases:
        dut.curr_shelf0_pos0.value = c0p0
        dut.curr_shelf0_pos1.value = c0p1
        dut.curr_shelf1_pos0.value = c1p0
        dut.curr_shelf1_pos1.value = c1p1
        dut.targ_shelf0_pos0.value = t0p0
        dut.targ_shelf0_pos1.value = t0p1
        dut.targ_shelf1_pos0.value = t1p0
        dut.targ_shelf1_pos1.value = t1p1
        await Timer(1, units='ns')
        result = dut.min_lifts_out.value.integer
        if result == expected or (result == -1 and expected == -1):
            passed += 1
        else:
            dut._log.error("Test failed: Current={%d,%d}/{%d,%d}, Target={%d,%d}/{%d,%d} => Result=%d, Expected=%d" \
                % (c0p0, c0p1, c1p0, c1p1, t0p0, t0p1, t1p0, t1p1, result, expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))