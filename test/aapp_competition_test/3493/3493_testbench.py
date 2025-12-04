import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_button_assign(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Test cases (original adapted + edge cases)
    test_grids = [
        (0b1111_1101_1011_1111, 3),  # Original sample expanded to 4x4 (k=3)
        (0b0100_0100_0000_0000, 0),  # Original n=2 case expanded to 4x4 (k=0)
        (0b1111_1111_1111_1111, 4),  # All possible (k=4)
        (0b1000_0100_0010_0001, 1),  # Single valid permutation
        (0b1001_0110_0110_1001, 2)   # Two valid permutations
    ]
    
    passed = 0
    dut._log.info(f"Starting {len(test_grids)} tests")
    
    for grid, expected in test_grids:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        dut.grid.value = grid
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing completion (max 8 cycles)
        for _ in range(10):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.k.value == expected:
            passed += 1
            dut._log.info(f"Test passed: k={dut.k.value} (expected {expected})")
        else:
            dut._log.error(f"Test failed: Grid={bin(grid)} => k={dut.k.value}, expected {expected}")
        
        await ClockCycles(dut.clk, 2)  // Cleanup cycles
    
    dut._log.info(f"{passed}/{len(test_grids)} tests passed")