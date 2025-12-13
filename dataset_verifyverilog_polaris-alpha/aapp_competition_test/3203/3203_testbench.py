import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
import math

@cocotb.test()
async def test_mission_assign(dut):
    # Create clock
    clock = cocotb.clock.Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (N=2 extended to 4x4 with 100% for unused positions)
    test_cases = [
        ( # Test 1 - N=2 scaled
            [[100,100,100,100], [50,50,100,100], [100,100,100,100], [100,100,100,100]],
            50.0 \* 100.0 \\/ 10000.0 # 0.5 = 0x00008000 in Q16.16
        ),
        ( # Test 2 - N=2 scaled
            [[0,50,100,100], [50,0,100,100], [100,100,100,100], [100,100,100,100]],
            25.0 \* 100.0 \\/ 10000.0 # 0.25 = 0x00004000
        ),
        ( # Test 3 - N=3 extended
            [[25,60,100,100], [13,0,50,100], [12,70,90,100], [100,100,100,100]],
            9.1 \* 100.0 \\/ 10000.0 # 0.091 ≈ 0x0001745D with rounding
        )
    ]

    passed = 0
    dut._log.info("Starting tests...")

    for case_idx, (prob_matrix, expected) in enumerate(test_cases):
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load input matrix
        for i in range(4):
            for j in range(4):
                dut.probabilities[i][j].value = prob_matrix[i][j]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 32 cycles)
        for _ in range(35):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check result - allow 1% tolerance due to fixed-point conversion
        actual_val = dut.max_prob.value.integer / 65536.0
        expected_hex = int(expected * 65536)
        tolerance = 657; # Allow ±0.01 in Q16.16 (≈1% error)
        if abs(dut.max_prob.value - expected_hex) <= tolerance:
            passed += 1
            dut._log.info(f"Test {case_idx+1} passed")
        else:
            dut._log.error(f"Test {case_idx+1} failed: Expected {expected_hex:08x} ({expected:.6f}), got {dut.max_prob.value:08x} ({actual_val:.6f})")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"