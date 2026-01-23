import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_lossy_sort_basic(dut):
    """Test the lossy sort module with basic examples"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    dut.current_number.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From problem statement
    inputs1 = [111, 1, 0, 111, 0]  # 111, 001, 000, 111, 000
    expected1 = [1, 1, 1, 111, 200]  # 001, 001, 001, 111, 200
    expected_changes1 = 2 + 0 + 0 + 0 + 1  # 111->001 (2), 0->001 (0), 0->001 (0), 111->111 (0), 0->200 (1) = 3
    
    dut.n.value = 4  # 5 numbers (n-1)
    dut.m.value = 2  # 3 digits (m-1)
    
    # Start sequence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    total_changes = 0
    results = []
    
    # Process each input
    for i, inp in enumerate(inputs1):
        # Wait for LOAD state (or when ready for input)
        await RisingEdge(dut.clk)
        dut.current_number.value = inp
        dut.load.value = 1
        await RisingEdge(dut.clk)
        dut.load.value = 0
        
        # Wait for output
        await Timer(50, units='ns')
        
        # Read result
        results.append(int(dut.result_number.value))
        
        # Wait a bit more
        await RisingEdge(dut.clk)
    
    # Wait for completion
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            total_changes = int(dut.changes_count.value)
            break
    
    # Verify results
    print(f"Results: {results}")
    print(f"Total changes: {total_changes}")
    
    # For test 1, we expect the sequence to be sorted
    for i in range(len(results)-1):
        if results[i] > results[i+1]:
            raise TestFailure(f"Sequence not sorted: {results}")
    
    print("Test 1 passed!")
    
    # Reset for test 2
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Reverse sorted sequence
    inputs2 = [999, 888, 777, 666, 555]
    dut.n.value = 4
    dut.m.value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results2 = []
    for inp in inputs2:
        await RisingEdge(dut.clk)
        dut.current_number.value = inp
        dut.load.value = 1
        await RisingEdge(dut.clk)
        dut.load.value = 0
        await Timer(50, units='ns')
        results2.append(int(dut.result_number.value))
    
    # Wait for done
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    print(f"Test 2 results: {results2}")
    
    # Verify sorted
    for i in range(len(results2)-1):
        if results2[i] > results2[i+1]:
            raise TestFailure(f"Sequence not sorted: {results2}")
    
    print(f"All tests passed! Total: 2/2")
