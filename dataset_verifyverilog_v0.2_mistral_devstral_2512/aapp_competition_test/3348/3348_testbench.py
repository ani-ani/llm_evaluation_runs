import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_bonbon_arrangement(dut):
    """Test the bonbon arrangement solver for 4x4 grid"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.count_a.value = 0
    dut.count_b.value = 0
    dut.count_c.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to check adjacency constraints
    def check_adjacency(grid):
        # grid is list of 16 chars
        for r in range(4):
            for c in range(4):
                idx = r * 4 + c
                curr = grid[idx]
                # Check right
                if c < 3:
                    if grid[idx+1] == curr:
                        return False
                # Check down
                if r < 3:
                    if grid[idx+4] == curr:
                        return False
        return True

    # Helper function to run a test case
    async def run_test(a, b, c, should_find):
        dut.count_a.value = a
        dut.count_b.value = b
        dut.count_c.value = c
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 20k cycles to be safe for backtracking)
        timeout = 0
        while not dut.done.value and timeout < 20000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        assert dut.done.value, "Test timed out"
        
        if should_find:
            assert dut.valid.value, f"Expected valid arrangement for {a},{b},{c} but got none"
            # Check output counts and adjacency
            grid_flat = []
            # Read packed 32-bit output
            grid_val = int(dut.grid_packed.value)
            char_map = ['A', 'B', 'C']
            counts = {'A': 0, 'B': 0, 'C': 0}
            
            for i in range(16):
                bits = (grid_val >> (i * 2)) & 0x3
                char = char_map[bits]
                grid_flat.append(char)
                counts[char] += 1
                
            assert counts['A'] == a, f"Count mismatch A: {counts['A']} vs {a}"
            assert counts['B'] == b, f"Count mismatch B: {counts['B']} vs {b}"
            assert counts['C'] == c, f"Count mismatch C: {counts['C']} vs {c}"
            assert check_adjacency(grid_flat), "Adjacency constraint violated"
            print(f"
Found valid grid for {a},{b},{c}:")
            for r in range(4):
                print(f"{''.join(grid_flat[r*4:(r+1)*4])}")
        else:
            assert not dut.valid.value, f"Expected impossible for {a},{b},{c} but found solution"
            print(f"Correctly determined impossible for {a},{b},{c}")

    # Test Case 1: Sample Input - Impossible
    await run_test(10, 3, 3, should_find=False)
    
    # Test Case 2: Sample Input - Should be possible (wait, problem says output for 6,5,5 is valid)
    # In 4x4, max of any one color is 8 (checkerboard). 6,5,5 is valid.
    await run_test(6, 5, 5, should_find=True)
    
    # Test Case 3: Impossible (Too many A)
    await run_test(12, 2, 2, should_find=False)
    
    # Test Case 4: Possible (Balanced)
    await run_test(4, 6, 6, should_find=True)
    
    # Test Case 5: Possible (Small A)
    await run_test(1, 7, 8, should_find=True)
