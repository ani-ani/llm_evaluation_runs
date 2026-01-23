import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_steward_support(dut):
    """Test the steward_support module"""
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.strength.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Example 1 (Input: 2 [1, 5], Output: 0)
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed inputs
    dut.strength.value = 1
    await RisingEdge(dut.clk)
    dut.strength.value = 5
    await RisingEdge(dut.clk)
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test Case 1 Failed: Expected 0, got {dut.result.value}"
    print("Test Case 1 Passed: [1, 5] -> 0")
    await RisingEdge(dut.clk)

    # Test Case 2: Example 2 (Input: 3 [1, 2, 5], Output: 1)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.strength.value = 1
    await RisingEdge(dut.clk)
    dut.strength.value = 2
    await RisingEdge(dut.clk)
    dut.strength.value = 5
    await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 1, f"Test Case 2 Failed: Expected 1, got {dut.result.value}"
    print("Test Case 2 Passed: [1, 2, 5] -> 1")
    await RisingEdge(dut.clk)

    # Test Case 3: All equal (Input: 3 [2, 2, 2], Output: 0)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.strength.value = 2
    await RisingEdge(dut.clk)
    dut.strength.value = 2
    await RisingEdge(dut.clk)
    dut.strength.value = 2
    await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 0, f"Test Case 3 Failed: Expected 0, got {dut.result.value}"
    print("Test Case 3 Passed: [2, 2, 2] -> 0")
    await RisingEdge(dut.clk)

    # Test Case 4: Multiple intermediates (Input: 4 [1, 2, 3, 4], Output: 2)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.strength.value = 1
    await RisingEdge(dut.clk)
    dut.strength.value = 2
    await RisingEdge(dut.clk)
    dut.strength.value = 3
    await RisingEdge(dut.clk)
    dut.strength.value = 4
    await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 2, f"Test Case 4 Failed: Expected 2, got {dut.result.value}"
    print("Test Case 4 Passed: [1, 2, 3, 4] -> 2")
    await RisingEdge(dut.clk)

    # Test Case 5: Single element (Input: 1 [5], Output: 0)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.strength.value = 5
    await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 0, f"Test Case 5 Failed: Expected 0, got {dut.result.value}"
    print("Test Case 5 Passed: [5] -> 0")

    print("All tests passed!")