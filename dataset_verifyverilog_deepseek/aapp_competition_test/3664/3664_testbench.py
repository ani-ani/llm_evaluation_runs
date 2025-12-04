import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_zamboni(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    # Test case 1: 5x5 grid, start at (3,3), 4 steps (scaled)
    test_cases = [
        (5,5,3,3,4, [
            '.....',
            '..BBC',
            '..A.C',
            '....C',
            '@DDDD'
        ])
    ]
    
    passed = 0
    for t in test_cases:
        dut.start.value = 0
        dut.r.value = t[0]
        dut.c.value = t[1]
        dut.start_i.value = t[2]
        dut.start_j.value = t[3]
        dut.n.value = t[4]
        expected = t[5]
        
        # Wait 2 cycles for initial reset to propagate
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Verify grid output
        error = False
        for i in range(t[0]):
            row = ''
            for j in range(t[1]):
                val = dut.grid[i][j].value.integer
                if val == 0: char = '.'
                elif val == 1: char = '@'
                else: char = chr(ord('A') + val - 2)
                row += char
            expected_row = expected[i]
            if row != expected_row:
                dut._log.error(f"Row {i} mismatch: got {row}, expected {expected_row}")
                error = True
        
        if not error:
            passed += 1
        await ClockCycles(dut.clk, 5)  # Add some settling cycles
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")