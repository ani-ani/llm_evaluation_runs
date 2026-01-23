import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_median_calculator(dut):
    """Test median calculator with various input sizes and values"""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to compute median in Python for verification
    def python_median(arr):
        sorted_arr = sorted(arr)
        n = len(sorted_arr)
        mid = n // 2
        if n % 2 == 1:
            return sorted_arr[mid]
        else:
            avg = (sorted_arr[mid-1] + sorted_arr[mid]) / 2
            return int(avg + 0.5)  # Round to nearest integer
    
    # Test cases
    test_cases = [
        ([3, 1, 2, 4, 5], 3),
        ([5], 5),
        ([6, 5], 6),  # 5.5 rounds to 6
        ([8, 1, 3, 9, 9, 2, 7], 7),
        ([10, 20, 30], 20),
        ([1, 2, 3, 4], 3),  # (2+3)/2 = 2.5 -> 3
        ([100, 200], 150),  # (100+200)/2 = 150
        ([1, 1, 1, 1, 1, 1, 1, 1], 1),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_array, expected in test_cases:
        # Wait for data_ready
        while not dut.data_ready.value:
            await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        dut.num_elements.value = len(test_array)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed data values
        for val in test_array:
            # Wait for data_ready
            while not dut.data_ready.value:
                await RisingEdge(dut.clk)
            dut.data_in.value = val & 0xFF
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
            dut.data_valid.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"Test FAILED: Timeout for input {test_array}")
            continue
        
        # Read result
        actual = int(dut.result.value)
        expected_calc = python_median(test_array)
        
        if actual == expected_calc and actual == expected:
            passed += 1
            print(f"Test PASSED: {test_array} -> {actual} (expected {expected})")
        else:
            print(f"Test FAILED: {test_array} -> {actual} (expected {expected}, python {expected_calc})")
        
        # Wait before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
