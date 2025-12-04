import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_perimeter(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock

    # Test cases (grid flattened, expected result)
    test_cases = [
        (  # Test 1: 2x2 all free (8x8 grid)
            int('0'*2 + '1'*6 + '0'*2 + '1'*6 + '1'*48, 2),
            7  # 2*(2+2)-1 = 7
        ),
        (  # Test 2: 4x4 sample from problem (padded to 8x8)
            int(
                '1' + '0' + '1'*2 + '1'*4 +  # Row0: X.XX -> 1011 then pad 4 1's
                '1' + '0'*2 + '1' + '1'*4 +  # Row1: X..X -> 1001
                '0'*2 + '1' + '0' + '1'*4 +  # Row2: ..X. -> 0010
                '0'*2 + '1'*2 + '1'*4 +       # Row3: ..XX -> 0011
                '1'*32,  # Rows 4-7 all blocked
                2
            ),
            9  # Best rectangle is 3x2 (2*(3+2)-1=9)
        ),
        (  # Test 3: 3x3 cross pattern
            int(
                '1' + '0' + '1' + '1'*5 +  # Row0: X.X -> 101
                '0' + '1' + '0' + '1'*5 +  # Row1: .X.
                '1' + '0' + '1' + '1'*5 +  # Row2: X.X
                '1'*40,  # Rows 3-7 blocked
                2
            ),
            3  # 2*(1+1)-1=3 (individual cells)
        )
    ]

    passed = 0
    dut._log.info(f"Starting {len(test_cases)} tests")

    for idx, (grid_val, expected) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load grid and start
        dut.grid_flat.value = grid_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 5000 cycles)
        for _ in range(5000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, f"Test {idx} timed out"

        # Check result
        result = dut.max_perimeter.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test {idx} PASSED: {result} == {expected}")
        else:
            dut._log.error(f"Test {idx} FAILED: Got {result}, expected {expected}")

        await RisingEdge(dut.clk)  # Wait one extra cycle

    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")