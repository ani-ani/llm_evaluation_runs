import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_sequential_search(dut):
    """Test sequential search module with multiple test cases"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.search_item.value = 0
    dut.array_flat.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case helper function
    async def run_search(array_values, search_value, expected_found, expected_index):
        # Flatten array (8 elements, each 8 bits): array[0] in [63:56], array[1] in [55:48], etc.
        flat = 0
        for i, val in enumerate(array_values):
            shift_amount = 56 - (i * 8)
            flat |= (val << shift_amount)
        
        dut.array_flat.value = flat
        dut.search_item.value = search_value
        await RisingEdge(dut.clk)
        
        # Start search
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (should take 9 cycles: 8 comparisons + 1 completion)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done signal")
        
        # Verify results
        if dut.found.value != expected_found:
            raise TestFailure(f"Test failed: found={dut.found.value}, expected={expected_found}")
        
        if dut.index.value != expected_index:
            raise TestFailure(f"Test failed: index={dut.index.value}, expected={expected_index}")
        
        print(f"Test passed: array={array_values}, search={search_value}, found={dut.found.value}, index={dut.index.value}")
        await RisingEdge(dut.clk)  # Clean cycle before next test
    
    # Test 1: Element 31 in array at position 3
    await run_search([11, 23, 58, 31, 56, 77, 43, 12], 31, 1, 3)
    
    # Test 2: Element 61 in array at position 7
    await run_search([12, 32, 45, 62, 35, 47, 44, 61], 61, 1, 7)
    
    # Test 3: Element 48 in array at position 6
    await run_search([9, 10, 17, 19, 22, 39, 48, 56], 48, 1, 6)
    
    # Test 4: Element not in array (edge case)
    await run_search([10, 20, 30, 40, 50, 60, 70, 80], 99, 0, 7)  # index 7 (3'b111) means -1
    
    # Test 5: Search for first element
    await run_search([10, 20, 30, 40, 50, 60, 70, 80], 10, 1, 0)
    
    # Test 6: Search for element equal to -1 representation (edge case)
    await run_search([255, 1, 2, 3, 4, 5, 6, 7], 255, 1, 0)
    
    print("
=== Summary: All 6 tests passed ===")

@cocotb.test()
async def test_sequential_search_edge_cases(dut):
    """Test edge cases for sequential search"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.search_item.value = 0
    dut.array_flat.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: All zeros, search for 0
    flat = 0  # All elements are 0
    dut.array_flat.value = flat
    dut.search_item.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value != 1 or dut.index.value != 0:
        raise TestFailure("Edge case failed: all zeros, search 0")
    print("Edge case 1 passed: all zeros, search 0 -> found at index 0")
    
    await RisingEdge(dut.clk)
    
    # Edge case: Last element match
    flat = 0
    for i in range(7):
        flat |= (i + 1) << (56 - i * 8)
    flat |= (99) << 0  # Last element at index 7
    dut.array_flat.value = flat
    dut.search_item.value = 99
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value != 1 or dut.index.value != 7:
        raise TestFailure("Edge case failed: last element match")
    print("Edge case 2 passed: last element match -> found at index 7")
    
    print("
=== Summary: All edge case tests passed ===")
