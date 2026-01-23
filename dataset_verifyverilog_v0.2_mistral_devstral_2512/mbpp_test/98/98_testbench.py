import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_multiply_num(dut):
    """Test multiply_num module with various test cases"""
    
    # Clock generation
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert decimal to Q16.16
    def to_q16_16(x):
        return int(x * 65536)
    
    # Helper function to convert Q16.16 to decimal
    def to_decimal(q):
        # Handle signed values
        if q >= 2**31:
            q = q - 2**32
        return q / 65536.0
    
    # Test cases (scaled for Q16.16)
    # Test 1: [8, 2, 3, -1, 7] -> product = -336, divide by 5 = -67.2
    test_cases = [
        {
            'name': 'Test 1: Mixed positive/negative',
            'inputs': [8, 2, 3, -1, 7],
            'expected': -67.2,
            'length': 5
        },
        {
            'name': 'Test 2: All negative',
            'inputs': [-10, -20, -30],
            'expected': -2000.0,
            'length': 3
        },
        {
            'name': 'Test 3: All positive',
            'inputs': [19, 15, 18],
            'expected': 1710.0,
            'length': 3
        },
        {
            'name': 'Test 4: Edge case - include zero',
            'inputs': [5, 0, 3],
            'expected': 0.0,
            'length': 3
        },
        {
            'name': 'Test 5: Powers of 2',
            'inputs': [2, 4, 8],
            'expected': 8.0,
            'length': 3
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test in test_cases:
        dut._log.info(f"Running {test['name']}")
        
        # Load data into module
        n = test['length']
        for i in range(n):
            # Set data and index
            q_value = to_q16_16(test['inputs'][i])
            dut.data_in.value = q_value & 0xFFFFFFFF  # Ensure 32-bit
            dut.index.value = i
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        
        # Deassert data_valid
        dut.data_valid.value = 0
        dut.data_in.value = 0
        
        # Wait a few cycles
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Assert start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (with timeout)
        max_cycles = 200
        cycles_waited = 0
        while not dut.done.value and cycles_waited < max_cycles:
            await RisingEdge(dut.clk)
            cycles_waited += 1
        
        if cycles_waited >= max_cycles:
            dut._log.error(f"Timeout in {test['name']}")
            continue
        
        # Read result
        result_q = int(dut.result.value)
        result_decimal = to_decimal(result_q)
        expected = test['expected']
        
        # Check with 1% tolerance (as specified)
        tolerance = abs(expected) * 0.01
        if tolerance < 0.01:
            tolerance = 0.01  # Minimum tolerance
        
        if abs(result_decimal - expected) <= tolerance:
            dut._log.info(f"PASS: {test['name']} - Result: {result_decimal:.4f}, Expected: {expected:.4f}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {test['name']} - Result: {result_decimal:.4f}, Expected: {expected:.4f}, Diff: {abs(result_decimal - expected):.4f}")
        
        # Reset for next test
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")