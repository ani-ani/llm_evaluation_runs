import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_count_element_in_list(dut):
    """Test counting sublists containing a particular element"""
    
    # Create clock and start it
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target_element.value = 0
    # Initialize all sublist elements to 0
    for i in range(4):
        for j in range(4):
            dut.sublists[i][j].value = 0
    
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Target = 1 in [[1, 3], [5, 7], [1, 11], [1, 15, 7]]
    # Expected: 3 sublists contain 1
    dut.target_element.value = 1
    
    # Sublist 0: [1, 3] -> elements at [0][0] and [0][1]
    dut.sublists[0][0].value = 1
    dut.sublists[0][1].value = 3
    dut.sublists[0][2].value = 0
    dut.sublists[0][3].value = 0
    
    # Sublist 1: [5, 7] -> no 1
    dut.sublists[1][0].value = 5
    dut.sublists[1][1].value = 7
    dut.sublists[1][2].value = 0
    dut.sublists[1][3].value = 0
    
    # Sublist 2: [1, 11] -> has 1
    dut.sublists[2][0].value = 1
    dut.sublists[2][1].value = 11
    dut.sublists[2][2].value = 0
    dut.sublists[2][3].value = 0
    
    # Sublist 3: [1, 15, 7] -> has 1
    dut.sublists[3][0].value = 1
    dut.sublists[3][1].value = 15
    dut.sublists[3][2].value = 7
    dut.sublists[3][3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for 6 cycles (latency)
    for _ in range(6):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 3, f"Test 1 Failed: Expected 3, got {dut.result.value}"
    print("Test 1 Passed: Found 1 in 3 out of 4 sublists")
    
    await RisingEdge(dut.clk)
    
    # Test Case 2: Target = 'A' (encoded as 65) in [['A', 'B'], ['A', 'C'], ['A', 'D', 'E'], ['B', 'C', 'D']]
    # Expected: 3 sublists contain 'A'
    dut.target_element.value = 65  # ASCII 'A'
    
    # Sublist 0: ['A', 'B']
    dut.sublists[0][0].value = 65
    dut.sublists[0][1].value = 66
    dut.sublists[0][2].value = 0
    dut.sublists[0][3].value = 0
    
    # Sublist 1: ['A', 'C']
    dut.sublists[1][0].value = 65
    dut.sublists[1][1].value = 67
    dut.sublists[1][2].value = 0
    dut.sublists[1][3].value = 0
    
    # Sublist 2: ['A', 'D', 'E']
    dut.sublists[2][0].value = 65
    dut.sublists[2][1].value = 68
    dut.sublists[2][2].value = 69
    dut.sublists[2][3].value = 0
    
    # Sublist 3: ['B', 'C', 'D']
    dut.sublists[3][0].value = 66
    dut.sublists[3][1].value = 67
    dut.sublists[3][2].value = 68
    dut.sublists[3][3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(6):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 3, f"Test 2 Failed: Expected 3, got {dut.result.value}"
    print("Test 2 Passed: Found 'A' in 3 out of 4 sublists")
    
    await RisingEdge(dut.clk)
    
    # Test Case 3: Target = 'E' (encoded as 69) in same list
    # Expected: 1 sublist contains 'E'
    dut.target_element.value = 69  # ASCII 'E'
    
    # Same sublist data as Test 2
    dut.sublists[0][0].value = 65
    dut.sublists[0][1].value = 66
    dut.sublists[0][2].value = 0
    dut.sublists[0][3].value = 0
    
    dut.sublists[1][0].value = 65
    dut.sublists[1][1].value = 67
    dut.sublists[1][2].value = 0
    dut.sublists[1][3].value = 0
    
    dut.sublists[2][0].value = 65
    dut.sublists[2][1].value = 68
    dut.sublists[2][2].value = 69
    dut.sublists[2][3].value = 0
    
    dut.sublists[3][0].value = 66
    dut.sublists[3][1].value = 67
    dut.sublists[3][2].value = 68
    dut.sublists[3][3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(6):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 1, f"Test 3 Failed: Expected 1, got {dut.result.value}"
    print("Test 3 Passed: Found 'E' in 1 out of 4 sublists")
    
    await RisingEdge(dut.clk)
    
    # Test Case 4: Target not present
    dut.target_element.value = 99  # Not in any sublist
    
    dut.sublists[0][0].value = 1
    dut.sublists[0][1].value = 2
    dut.sublists[0][2].value = 0
    dut.sublists[0][3].value = 0
    
    dut.sublists[1][0].value = 3
    dut.sublists[1][1].value = 4
    dut.sublists[1][2].value = 0
    dut.sublists[1][3].value = 0
    
    dut.sublists[2][0].value = 5
    dut.sublists[2][1].value = 6
    dut.sublists[2][2].value = 0
    dut.sublists[2][3].value = 0
    
    dut.sublists[3][0].value = 7
    dut.sublists[3][1].value = 8
    dut.sublists[3][2].value = 0
    dut.sublists[3][3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(6):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 0, f"Test 4 Failed: Expected 0, got {dut.result.value}"
    print("Test 4 Passed: Element not found in any sublist")
    
    # Summary
    print("
=== ALL TESTS PASSED (4/4) ===")