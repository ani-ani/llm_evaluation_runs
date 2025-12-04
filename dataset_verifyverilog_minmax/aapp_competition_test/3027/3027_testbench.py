import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

@cocotb.test()
async def test_stamp(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create 10ns period clock
    cocotb.start_soon(clock.start())  # Start clock
    
    # Custom test cases (scaled down from original examples)
    test_cases = [
        (4, 4, '
'.join(['..#.', '.###', '.###', '..#.']), 4),  # Original min=8 scaled to 4x4
        (3, 3, '
'.join(['...', '.#.', '...']), 1),  # Same as original
        (2, 6, '
'.join(['.#####', '#####.']), 5),  # Width clipped to 6 (max 8)
        (2, 5, '
'.join(['.#.#.', '#.#.#']), 3)   # Same as original
    ]
    
    # Convert test patterns to bit vectors
    tests = []
    for h, w, pattern, expected in test_cases:
        # Flatten pattern to 64-bit vector (row-major, 1'", h, w, flat, expected)
    
    # Initialize and reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(15, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(tests)
    
    for h, w, paper_vector, expected in tests:
        # Load inputs
        dut.grid_height.value = h
        dut.grid_width.value = w
        dut.paper_mark.value = paper_vector
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.min_nubs.value == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: h={h} w={w} expected={expected} got={dut.min_nubs.value}")
        
        await RisingEdge(dut.clk)  # Extra cycle between tests
    
    dut._log.info(f"{passed}/{total} tests passed")