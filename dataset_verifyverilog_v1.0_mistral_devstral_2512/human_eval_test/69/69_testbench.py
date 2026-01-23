import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def calculate_expected(arr):
    """Python reference implementation for the adapted problem."""
    # Count frequencies for values 1-15
    freq = {}
    for x in arr:
        if 0 < x <= 15:
            freq[x] = freq.get(x, 0) + 1
    
    # Check values from 15 down to 1
    for v in range(15, 0, -1):
        if v in freq and freq[v] >= v:
            return v
    return -1

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_search_max_valid(dut):
    """Test the search_max_valid module."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.index.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (array_elements, expected_result)
    # We keep the original test cases but filter out elements > 15 or out of range
    test_cases = [
        ([4, 1, 2, 2, 3, 1], 2),      # From problem description
        ([1, 2, 2, 3, 3, 3, 4, 4, 4], 3),
        ([5, 5, 4, 4, 4], -1),
        ([5, 5, 5, 5, 1], 1),
        ([4, 1, 4, 1, 4, 4], 4),
        ([3, 3], -1),
        ([8, 8, 8, 8, 8, 8, 8, 8], 8),
        ([2, 3, 3, 2, 2], 2),
        ([2, 7, 8, 8, 4, 8, 7, 3, 9, 6, 5, 10, 4, 3, 6, 7, 1, 7, 4, 10, 8, 1], 1),
        ([3, 2, 8, 2], 2),
        ([6, 7, 1, 8, 8, 10, 5, 8, 5, 3, 10], 1),
        ([8, 8, 3, 6, 5, 6, 4], -1),
        ([1, 9, 10, 1, 3], 1),
        ([1], 1),
        ([10], -1),
        ([9, 7, 7, 2, 4, 7, 2, 10, 9, 7, 5, 7, 2], 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (arr, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input {arr}, Expected {expected}")
        
        # 1. Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 2. Load data (feed array elements)
        # Note: We feed elements one by one. The module increments frequency internally.
        # In this testbench, we simulate the user driving the input port.
        # However, our module interface expects 'data_in' and 'index' to come from somewhere.
        # To make this a standalone test, we simulate the loading process strictly.
        # The module has no internal RAM for storage in this specific prompt design,
        # it expects the frequency logic to be implemented internally or logic to read inputs.
        # The prompt said: "Use a 16x4-bit memory... On valid_in, increment frequency."
        # This implies the module must have internal storage.
        
        for idx, val in enumerate(arr):
            if val > 15: continue # Skip out of bounds for this test
            dut.data_in.value = val
            dut.index.value = idx  # Index is technically redundant for frequency counting but required by interface
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # 3. Signal done_in to start computation
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        
        # 4. Wait for done signal with cycle timeout
        MAX_CYCLES = 20
        found_done = False
        
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
                
            if dut.done.value == 1:
                found_done = True
                break
        
        if not found_done:
            raise TestFailure(f"Test {i+1} Timeout: Done signal not asserted after {MAX_CYCLES} cycles")
        
        # 5. Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
            
        result = int(dut.result.value)
        
        # Handle signed -1 (0xFF in 8-bit)
        if result > 127:
            result = result - 256
            
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        
        passed += 1
        # Small delay between tests
        await Timer(50, units='ns')
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
