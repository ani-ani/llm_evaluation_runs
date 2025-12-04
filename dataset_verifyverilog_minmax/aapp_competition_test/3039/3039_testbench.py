import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_cube_fold(dut):
    # Convert test cases to 36-bit values (row-major order)
    test_cases = [
        # Test 1: Straight line (cannot fold)
        (0b000000_000000_111111_000000_000000_000000 << 24, 0),
        # Test 2: Valid net (can fold)
        (0b000000_100000_111100_100000_000000_000000 << 24, 1),
        # Test 3: Cross pattern (cannot fold)
        (0b001100_000100_001100_000100_000000_000000 << 24, 0),
        # Test 4: Sample valid net (can fold)
        (0b000000_000100_000100_001110_001000_000000 << 24, 1)
    ]
    passed = 0
    for grid_val, expected in test_cases:
        dut.grid.value = grid_val
        await Timer(1, units='ns')
        actual = dut.foldable.value
        if actual == expected:
            passed += 1
        else:
            dut._log.error("Test failed: Grid=%036b Expected=%d Actual=%d" % (grid_val, expected, actual))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))