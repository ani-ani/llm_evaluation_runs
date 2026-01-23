import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_bst_insertion(dut):
    """Test BST insertion with depth tracking for N=8"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Simple increasing sequence [1,2,3,4]
    print("
Test Case 1: Inserting [1,2,3,4]")
    expected_depths = [0, 1, 3, 6]
    inputs = [1, 2, 3, 4]
    
    for i, (val, expected) in enumerate(zip(inputs, expected_depths)):
        dut.data_in.value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test case 1, insertion {i+1}: Done signal not asserted within timeout")
        
        actual = int(dut.cumulative_depth.value)
        print(f"  Insert {val}: Expected {expected}, Got {actual}")
        if actual != expected:
            raise TestFailure(f"Test case 1, insertion {i+1}: Expected {expected}, Got {actual}")
    
    # Reset for test case 2
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: Random sequence [3,2,4,1,5]
    print("
Test Case 2: Inserting [3,2,4,1,5]")
    expected_depths = [0, 1, 2, 4, 6]
    inputs = [3, 2, 4, 1, 5]
    
    for i, (val, expected) in enumerate(zip(inputs, expected_depths)):
        dut.data_in.value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test case 2, insertion {i+1}: Done signal not asserted within timeout")
        
        actual = int(dut.cumulative_depth.value)
        print(f"  Insert {val}: Expected {expected}, Got {actual}")
        if actual != expected:
            raise TestFailure(f"Test case 2, insertion {i+1}: Expected {expected}, Got {actual}")
    
    # Reset for test case 3
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: More complex sequence [3,5,1,6,8,7,2,4]
    print("
Test Case 3: Inserting [3,5,1,6,8,7,2,4]")
    expected_depths = [0, 1, 2, 4, 7, 11, 13, 15]
    inputs = [3, 5, 1, 6, 8, 7, 2, 4]
    
    for i, (val, expected) in enumerate(zip(inputs, expected_depths)):
        dut.data_in.value = val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test case 3, insertion {i+1}: Done signal not asserted within timeout")
        
        actual = int(dut.cumulative_depth.value)
        print(f"  Insert {val}: Expected {expected}, Got {actual}")
        if actual != expected:
            raise TestFailure(f"Test case 3, insertion {i+1}: Expected {expected}, Got {actual}")
    
    print("
All tests passed!")
