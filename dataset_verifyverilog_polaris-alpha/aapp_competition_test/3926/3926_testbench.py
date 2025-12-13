import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_maze(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases adapted from originals (scaled to max 8x8)
    test_mazes = [
        (  # Original input 1 (4x5 scaled to 8x8 - preserve structure)
            # .....
            # .***.
            # ...**
            # *....
            3, 1, 1, 2,
            0b00000_001110_00011_10000_000000000000000000000000,
            10
        ),
        (  # Original input 2 (4x4)
            1, 1, 0, 1,
            0b0000_0010_0000_0000_000000000000000000000000,
            7
        ),
        (  # Single cell test
            0, 0, 0, 0,
            0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000001,
            1
        )
    ]

    passed = 0
    for test_id, (r, c, l, rt, g, expected) in enumerate(test_mazes):
        # Reset and initialize
        await reset()
        dut.start_row.value = r
        dut.start_col.value = c
        dut.max_left.value = l
        dut.max_right.value = rt
        dut.grid.value = g
        dut.start.value = 1
        
        # Wait 1 cycle to start processing
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 64 cycles)
        timeout = 70
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        # Verify results
        if timeout == 0:
            dut._log.error(f"Test {test_id} timed out")
        elif dut.reachable_count.value != expected:
            dut._log.error(f"Test {test_id} failed: Got {dut.reachable_count.value}, expected {expected}")
        else:
            passed += 1

    dut._log.info(f"{passed}/{len(test_mazes)} tests passed")
    assert passed == len(test_mazes)