import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to convert grid to test input format
def create_grid_data(grid):
    """Convert 4x4 grid to list of (row, col, value) tuples"""
    data = []
    for i in range(4):
        for j in range(4):
            # grid[i][j] is 0 for free, 1 for forest
            data.append((i, j, grid[i][j]))
    return data

async def load_grid(dut, grid):
    """Load 4x4 grid into DUT"""
    dut.grid_wr.value = 1
    for row in range(4):
        for col in range(4):
            dut.row_idx.value = row
            dut.col_idx.value = col
            dut.grid_in.value = grid[row][col]
            await RisingEdge(dut.clk)
    dut.grid_wr.value = 0

async def run_test(dut, grid, expected_result, test_name):
    """Run single test case"""
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_wr.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load grid
    await load_grid(dut, grid)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1 and dut.valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure(f"{test_name}: Timeout waiting for done signal")
    
    # Check result
    actual = int(dut.result.value)
    if actual != expected_result:
        raise TestFailure(f"{test_name}: Expected {expected_result}, got {actual}")
    
    print(f"{test_name}: PASS (result={actual})")

@cocotb.test()
async def test_treasure_island(dut):
    """Test treasure island module with multiple cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await Timer(20, units="ns")
    
    tests_passed = 0
    tests_total = 0
    
    # Test 1: 2x2 example (scaled to 4x4 with padding)
    # Original: 2x2 all free -> answer 2
    # In 4x4, minimal interesting case
    grid1 = [
        [0, 0, 1, 1],  # ..##
        [0, 0, 1, 1],  # ..##
        [1, 1, 1, 1],  # ####
        [1, 1, 1, 1]   # ####
    ]
    tests_total += 1
    try:
        await run_test(dut, grid1, 2, "Test1_2x2_all_free")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test1 FAILED: {e}")
    
    # Test 2: 4x4 example from problem
    # ....
    # #.#.
    # ....
    # .#..
    grid2 = [
        [0, 0, 0, 0],
        [1, 0, 1, 0],
        [0, 0, 0, 0],
        [0, 1, 0, 0]
    ]
    tests_total += 1
    try:
        await run_test(dut, grid2, 1, "Test2_4x4_example")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test2 FAILED: {e}")
    
    # Test 3: 3x4 example (scaled to 4x4)
    # ....
    # .##.
    # ....
    grid3 = [
        [0, 0, 0, 0],
        [0, 1, 1, 0],
        [0, 0, 0, 0],
        [1, 1, 1, 1]   # padding
    ]
    tests_total += 1
    try:
        await run_test(dut, grid3, 2, "Test3_3x4_example")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test3 FAILED: {e}")
    
    # Test 4: Blocked path - no route
    # .#..
    # #...
    # ...#
    # ..#.
    grid4 = [
        [0, 1, 0, 0],
        [1, 0, 0, 0],
        [0, 0, 0, 1],
        [0, 0, 1, 0]
    ]
    tests_total += 1
    try:
        await run_test(dut, grid4, 0, "Test4_no_path")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test4 FAILED: {e}")
    
    # Test 5: Single critical cell
    # .###
    # ..#.
    # ..#.
    # ###.
    grid5 = [
        [0, 1, 1, 1],
        [0, 0, 1, 0],
        [0, 0, 1, 0],
        [1, 1, 1, 0]
    ]
    tests_total += 1
    try:
        await run_test(dut, grid5, 1, "Test5_critical_cell")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test5 FAILED: {e}")
    
    # Test 6: Two independent paths (answer 2)
    # ....
    # ....
    # ....
    # ....
    grid6 = [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
    ]
    tests_total += 1
    try:
        await run_test(dut, grid6, 2, "Test6_all_free")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test6 FAILED: {e}")
    
    # Test 7: Forest at start or end (should handle gracefully)
    # Start and end are guaranteed free, but test near them
    grid7 = [
        [0, 0, 0, 0],
        [0, 1, 1, 1],
        [0, 1, 1, 1],
        [0, 0, 0, 0]
    ]
    tests_total += 1
    try:
        await run_test(dut, grid7, 2, "Test7_maze")
        tests_passed += 1
    except TestFailure as e:
        print(f"Test7 FAILED: {e}")
    
    print(f"
=== SUMMARY: {tests_passed}/{tests_total} tests passed ===")
    assert tests_passed == tests_total, f"Only {tests_passed} out of {tests_total} tests passed"
}