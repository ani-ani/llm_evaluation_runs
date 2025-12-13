import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_club_fencing(dut):
    # Test cases (scaled to 4x4)
    # Original test 1: converted to 4x4 grid
    test_cases = [
        # B,H,R,C, grid (4x4 padded with 0)
        (9, 1, 4, 4, 0x33333333, 176),  # Expected cost scaled
        # Original test 2: converted to 4x4 grid
        (5, 2, 4, 4, 0x63232256, 66)    # Expected cost scaled
    ]
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    passed = 0
    for idx, (B_val, H_val, R_val, C_val, grid_val, expected) in enumerate(test_cases):
        # Reset and initialize
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Set inputs
        dut.B.value = B_val
        dut.H.value = H_val
        dut.R.value = R_val
        dut.C.value = C_val
        dut.grid.value = grid_val
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (max 1000 cycles)
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        # Check result
        actual = dut.total_cost.value.integer
        if actual == expected:
            passed += 1
        else:
            dut._log.error(
                f"Test {idx} failed: Expected {expected}, got {actual}
                B={B_val}, H={H_val}, R={R_val}, C={C_val}, grid={hex(grid_val)}"
            )
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")