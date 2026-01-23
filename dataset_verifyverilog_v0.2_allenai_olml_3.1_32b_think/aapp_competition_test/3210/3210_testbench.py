import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

class DotsAndBoxesTester:
    def __init__(self, dut):
        self.dut = dut
        self.dut.rst_n.value = 1
        self.dut.start.value = 0
        self.dut.row_data.value = 0
        self.dut.row_index.value = 0
        self.dut.N.value = 0

    async def reset(self):
        self.dut.rst_n.value = 0
        await Timer(10, units='ns')
        self.dut.rst_n.value = 1
        await Timer(10, units='ns')

    async def load_grid(self, grid_str, N):
        """Load ASCII grid into DUT"""
        rows = grid_str.strip().split('
')
        self.dut.N.value = N
        await RisingEdge(self.dut.clk)
        
        for i, row in enumerate(rows):
            self.dut.row_index.value = i
            # Convert string to byte array
            row_bytes = [ord(c) for c in row]
            # For simplicity, we'll load one char per cycle (padded to 8 bits)
            for j, byte_val in enumerate(row_bytes):
                self.dut.row_data.value = byte_val
                await RisingEdge(self.dut.clk)
                # In real design, we'd have an address to store, but for this
                # simplified test we're just demonstrating the interface

    async def compute(self):
        """Start computation and wait for done"""
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        
        # Wait for done signal
        timeout = 1000
        for i in range(timeout):
            if self.dut.done.value == 1:
                break
            await RisingEdge(self.dut.clk)
        else:
            raise TimeoutError("Computation did not complete")

@cocotb.test()
async def test_dots_and_boxes_basic(dut):
    """Test basic Dots and Boxes computation"""
    tester = DotsAndBoxesTester(dut)
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await tester.reset()
    
    # Test Case 1: N=2, empty grid
    # Expected: 4 moves (all edges can be drawn without completing a box)
    # Grid: *.*
...
*.*
 (3x3 for N=2)
    grid1 = "*.*
...
*.*
"
    await tester.load_grid(grid1, 2)
    await tester.compute()
    result1 = int(dut.result.value)
    print(f"Test 1 (N=2, empty): Result={result1}, Expected=4")
    assert result1 == 4, f"Expected 4, got {result1}"
    
    # Test Case 2: N=3, some edges already present
    # Expected: 3 moves
    grid2 = "*-*.*
|.|.|
*.*-*
|...|
*.*.*
"
    await tester.load_grid(grid2, 3)
    await tester.compute()
    result2 = int(dut.result.value)
    print(f"Test 2 (N=3, partial): Result={result2}, Expected=3")
    assert result2 == 3, f"Expected 3, got {result2}"
    
    # Test Case 3: N=4, more complex
    # Expected: 5 moves
    grid3 = "*-*-*.*
|...|..
*-*-*-*
|.....|
*.*.*-*
|.....|
*-*-*-*
"
    await tester.load_grid(grid3, 4)
    await tester.compute()
    result3 = int(dut.result.value)
    print(f"Test 3 (N=4, partial): Result={result3}, Expected=5")
    assert result3 == 5, f"Expected 5, got {result3}"
    
    # Test Case 4: Maximum case - N=2 with one edge already used
    # Should still be able to draw 3 more moves
    grid4 = "*.*
-..
*.*
"
    await tester.load_grid(grid4, 2)
    await tester.compute()
    result4 = int(dut.result.value)
    print(f"Test 4 (N=2, one edge): Result={result4}, Expected=3")
    assert result4 == 3, f"Expected 3, got {result4}"
    
    print(f"
All tests passed!")

@cocotb.test()
async def test_dots_and_boxes_edge_cases(dut):
    """Test edge cases"""
    tester = DotsAndBoxesTester(dut)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await tester.reset()
    
    # Test Case 5: N=3, maximum possible moves
    # Grid with minimal edges present
    grid5 = "*.*.*
.....
*.*.*
.....
*.*.*
"
    await tester.load_grid(grid5, 3)
    await tester.compute()
    result5 = int(dut.result.value)
    print(f"Test 5 (N=3, empty): Result={result5}, Expected=9")
    assert result5 == 9, f"Expected 9, got {result5}"
    
    # Test Case 6: N=4, just dots
    grid6 = "*.*.*.*
.......
*.*.*.*
.......
*.*.*.*
.......
*.*.*.*
"
    await tester.load_grid(grid6, 4)
    await tester.compute()
    result6 = int(dut.result.value)
    print(f"Test 6 (N=4, empty): Result={result6}, Expected=24")
    # For N=4: total edges = 2*4*3 = 24, max without box = 24
    assert result6 == 24, f"Expected 24, got {result6}"
    
    print(f"
All edge case tests passed!")