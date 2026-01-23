import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_max_subarray_sum(dut):
    """Test maximum subarray sum with Kadane's algorithm"""
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        {
            "name": "Test 1",
            "array": [-2, -3, 4, -1, -2, 1, 5, -3],
            "expected": 7
        },
        {
            "name": "Test 2",
            "array": [-3, -4, 5, -2, -3, 2, 6, -4],
            "expected": 8
        },
        {
            "name": "Test 3",
            "array": [-4, -5, 6, -3, -4, 3, 7, -5],
            "expected": 10
        },
        {
            "name": "Test 4 - All negatives",
            "array": [-1, -2, -3, -4, -5, -6, -7, -8],
            "expected": 0
        },
        {
            "name": "Test 5 - All positives",
            "array": [10, 20, 30, 40, 50, 60, 70, 80],
            "expected": 360
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test in test_cases:
        dut._log.info(f"Running {test['name']}: array={test['array']}, expected={test['expected']}")
        
        # Reset for new test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load array elements
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for i, val in enumerate(test['array']):
            dut.data_in.value = val if val >= 0 else (256 + val)  # Convert to 2's complement
            dut.index.value = i
            await RisingEdge(dut.clk)
        
        # Wait for computation to complete
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Wait until done is asserted
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 20:
            raise TestFailure(f"{test['name']}: Done signal not asserted within timeout")
        
        # Read result
        result = dut.result.value
        if result.is_resolvable:
            result_int = int(result)
            if result_int > 127:
                result_int = result_int - 256
            
            if result_int == test['expected']:
                dut._log.info(f"{test['name']}: PASSED (result={result_int})")
                passed += 1
            else:
                raise TestFailure(f"{test['name']}: FAILED - Expected {test['expected']}, got {result_int}")
        else:
            raise TestFailure(f"{test['name']}: Result is not resolvable")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"