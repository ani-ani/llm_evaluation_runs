import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_even_pair_counter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.load.value = 0
    dut.compute.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [5, 4, 7, 2, 1] -> 4 pairs
    # 5(odd), 4(even), 7(odd), 2(even), 1(odd)
    # Even pairs: (4,2) -> 1
    # Odd pairs: (5,7), (5,1), (7,1) -> 3
    # Total: 4
    test_data_1 = [5, 4, 7, 2, 1, 0, 0, 0]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, val in enumerate(test_data_1):
        dut.data_in.value = val
        dut.index.value = i
        dut.load.value = 1
        await RisingEdge(dut.clk)
    
    dut.load.value = 0
    dut.compute.value = 1
    await RisingEdge(dut.clk)
    dut.compute.value = 0
    await Timer(1, units='ns')
    
    if dut.valid.value == 0:
        raise TestFailure("Valid not high after compute")
    
    result = int(dut.result.value)
    print(f"Test 1: Expected 4, Got {result}")
    if result != 4:
        raise TestFailure(f"Test 1 failed: expected 4, got {result}")
    
    # Test Case 2: [7, 2, 8, 1, 0, 5, 11] -> 9 pairs
    # 7(odd), 2(even), 8(even), 1(odd), 0(even), 5(odd), 11(odd), 0(even)
    # Even: 2,8,0,0 -> 4 elements -> 6 pairs
    # Odd: 7,1,5,11 -> 4 elements -> 6 pairs
    # Total: 12, but expected 9...
    # Wait: input is only 7 elements: [7,2,8,1,0,5,11]
    # Even: 2,8,0 -> 3 elements -> 3 pairs
    # Odd: 7,1,5,11 -> 4 elements -> 6 pairs
    # Total: 9. Correct.
    test_data_2 = [7, 2, 8, 1, 0, 5, 11, 0]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, val in enumerate(test_data_2):
        dut.data_in.value = val
        dut.index.value = i
        dut.load.value = 1
        await RisingEdge(dut.clk)
    
    dut.load.value = 0
    dut.compute.value = 1
    await RisingEdge(dut.clk)
    dut.compute.value = 0
    await Timer(1, units='ns')
    
    result = int(dut.result.value)
    print(f"Test 2: Expected 9, Got {result}")
    if result != 9:
        raise TestFailure(f"Test 2 failed: expected 9, got {result}")
    
    # Test Case 3: [1, 2, 3] -> 1 pair
    # 1(odd), 2(even), 3(odd)
    # Even pairs: none
    # Odd pairs: (1,3) -> 1
    # Total: 1
    test_data_3 = [1, 2, 3, 0, 0, 0, 0, 0]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, val in enumerate(test_data_3):
        dut.data_in.value = val
        dut.index.value = i
        dut.load.value = 1
        await RisingEdge(dut.clk)
    
    dut.load.value = 0
    dut.compute.value = 1
    await RisingEdge(dut.clk)
    dut.compute.value = 0
    await Timer(1, units='ns')
    
    result = int(dut.result.value)
    print(f"Test 3: Expected 1, Got {result}")
    if result != 1:
        raise TestFailure(f"Test 3 failed: expected 1, got {result}")
    
    # Additional edge case: all even
    test_data_4 = [2, 4, 6, 8, 0, 0, 0, 0]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, val in enumerate(test_data_4):
        dut.data_in.value = val
        dut.index.value = i
        dut.load.value = 1
        await RisingEdge(dut.clk)
    
    dut.load.value = 0
    dut.compute.value = 1
    await RisingEdge(dut.clk)
    dut.compute.value = 0
    await Timer(1, units='ns')
    
    result = int(dut.result.value)
    # 5 even numbers (2,4,6,8,0): 5*4/2 = 10 pairs (but we loaded 8 elements, 5 of which are even)
    # Wait, test_data_4 has 4 non-zero evens + 4 zeros (even) = 8 evens
    # 8 evens: 8*7/2 = 28 pairs
    expected = 28
    print(f"Test 4: Expected {expected}, Got {result}")
    if result != expected:
        raise TestFailure(f"Test 4 failed: expected {expected}, got {result}")
    
    print("All tests passed!")