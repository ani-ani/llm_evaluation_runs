import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_search_frequency(dut):
    """Test the search_frequency module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_size.value = 0
    for i in range(8):
        dut.data[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (data_array, array_size, expected_result)
    # result 15 means -1 (no valid value)
    test_cases = [
        ([4, 1, 2, 2, 3, 1, 0, 0], 6, 2),      # freq 2:1, 1:2, 2:2, 3:1, 4:1 -> max valid is 2
        ([1, 2, 2, 3, 3, 3, 4, 4], 8, 3),      # freq 1:1, 2:2, 3:3, 4:2 -> max valid: 3 (freq 3>=3)
        ([5, 5, 4, 4, 4, 0, 0, 0], 5, 15),     # freq 4:3, 5:2 -> 4 needs 4, 5 needs 5 -> none valid
        ([1, 2, 2, 3, 2, 0, 0, 0], 5, 2),      # freq 1:1, 2:3, 3:1 -> 3 needs 3, has 1 -> invalid; 2 has 3 >= 2
        ([8, 8, 8, 8, 8, 8, 8, 8], 8, 8),      # freq 8:8 -> 8>=8
        ([3, 3, 0, 0, 0, 0, 0, 0], 2, 15),     # freq 3:2 -> 2<3 -> invalid
        ([1, 0, 0, 0, 0, 0, 0, 0], 1, 1),      # freq 1:1 -> 1>=1
        ([10, 0, 0, 0, 0, 0, 0, 0], 1, 15),    # freq 10:1 -> 1<10 -> invalid
        ([5, 5, 5, 5, 1, 0, 0, 0], 5, 1),      # freq 5:4 (4<5 invalid), freq 1:1 (1>=1 valid)
        ([4, 1, 4, 1, 4, 4, 0, 0], 6, 4),      # freq 1:2, 4:4 -> 4>=4 valid
        ([2, 3, 3, 2, 2, 0, 0, 0], 5, 2),      # freq 2:3, 3:2 -> 3 needs 3, has 2; 2 needs 2, has 3
        ([8, 8, 8, 8, 8, 8, 8, 8], 8, 8),      # duplicate to verify
    ]
    
    passed = 0
    total = len(test_cases)
    
    for data_array, size, expected in test_cases:
        # Set inputs
        dut.array_size.value = size
        for i in range(8):
            dut.data[i].value = data_array[i] if i < len(data_array) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout waiting for done. Data: {data_array}")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Test failed: data={data_array}, size={size}, expected={expected}, got={actual}")
        
        passed += 1
        await RisingEdge(dut.clk)  # Spacing between tests
    
    print(f"
=== Test Summary: {passed}/{total} tests passed ===")