import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

def count_connected_subsets(R, C):
    """Python reference implementation to verify the Verilog module."""
    rows = R
    cols = C
    total_cells = rows * cols
    total = 0
    
    # Iterate all non-empty subsets
    for mask in range(1, 1 << total_cells):
        # Check connectivity
        # Find first bit
        start = -1
        for i in range(total_cells):
            if (mask >> i) & 1:
                start = i
                break
        
        if start == -1:
            continue
            
        # Flood fill
        frontier = 1 << start
        visited = 0
        
        # Since max 16 cells, 16 steps are enough to propagate
        for _ in range(total_cells):
            visited |= frontier
            next_frontier = 0
            
            # Expand neighbors
            for j in range(total_cells):
                if (frontier >> j) & 1:
                    r, c = divmod(j, cols)
                    # Check 4 neighbors
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < rows and 0 <= nc < cols:
                            idx = nr * cols + nc
                            if (mask >> idx) & 1:
                                next_frontier |= (1 << idx)
            frontier = next_frontier
            
        if visited == mask:
            total += 1
            
    return total

@cocotb.test()
async def test_polygons(dut):
    """Test count_polygons module with various R and C values."""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.R.value = 0
    dut.C.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (R, C) pairs
    test_cases = [
        (1, 1),
        (1, 2),
        (2, 2),
        (1, 3),
        (2, 3),
        (3, 3),
        (1, 4),
        (2, 4),
        (4, 4)  # Max case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for r, c in test_cases:
        # Calculate expected value
        expected = count_connected_subsets(r, c)
        
        # Start computation
        dut.R.value = r
        dut.C.value = c
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 2000000: # Safety timeout
                raise TestFailure(f"Timeout for R={r}, C={c}")
        
        # Read result
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            print(f"R={r}, C={c}: OK (Result={result})")
        else:
            print(f"R={r}, C={c}: FAIL (Expected={expected}, Got={result})")
            raise TestFailure(f"Mismatch for R={r}, C={c}. Expected {expected}, got {result}")
    
    print(f"
Summary: {passed}/{total} tests passed")
