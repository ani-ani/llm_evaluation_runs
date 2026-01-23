import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to convert signed 8-bit integer to Python signed int
def to_signed_8(value):
    if value & 0x80:
        return value - 256
    return value

# Helper function to convert Python signed int to signed 8-bit representation
def from_signed_8(value):
    if value < 0:
        return value + 256
    return value

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_filter_positive(dut):
    """Test the filter_positive module with various test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    for i in range(8):
        dut.data[i].value = 0
    
    # Wait for a few clock cycles
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (input_array, length, expected_result_array)
    # Input arrays are 8 elements long, pad with zeros if shorter
    test_cases = [
        # Case 1: Mixed negative and positive
        # Input: [-1, -2, 4, 5, 6], Length: 5
        # Expected: [4, 5, 6], Result Len: 3
        {
            "input": [-1, -2, 4, 5, 6, 0, 0, 0],
            "length": 5,
            "expected_result": [4, 5, 6, 0, 0, 0, 0, 0],
            "expected_len": 3
        },
        # Case 2: Mix with zeros and duplicates
        # Input: [5, 3, -5, 2, 3, 3, 9, 0, 123, 1, -10] -> Scaled to 8 elements
        # Let's use: [5, 3, -5, 2, 3, 3, 9, 0]
        # Expected: [5, 3, 2, 3, 3, 9], Result Len: 6
        {
            "input": [5, 3, -5, 2, 3, 3, 9, 0],
            "length": 8,
            "expected_result": [5, 3, 2, 3, 3, 9, 0, 0],
            "expected_len": 6
        },
        # Case 3: All negatives
        # Input: [-1, -2], Length: 2
        # Expected: [], Result Len: 0
        {
            "input": [-1, -2, 0, 0, 0, 0, 0, 0],
            "length": 2,
            "expected_result": [0, 0, 0, 0, 0, 0, 0, 0],
            "expected_len": 0
        },
        # Case 4: Empty list
        # Input: [], Length: 0
        # Expected: [], Result Len: 0
        {
            "input": [0, 0, 0, 0, 0, 0, 0, 0],
            "length": 0,
            "expected_result": [0, 0, 0, 0, 0, 0, 0, 0],
            "expected_len": 0
        },
        # Case 5: All positive
        # Input: [1, 2, 3], Length: 3
        # Expected: [1, 2, 3], Result Len: 3
        {
            "input": [1, 2, 3, 0, 0, 0, 0, 0],
            "length": 3,
            "expected_result": [1, 2, 3, 0, 0, 0, 0, 0],
            "expected_len": 3
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: Input={tc['input'][:tc['length']]}, Len={tc['length']}")
        
        # Load input array and length
        for j in range(8):
            val = tc["input"][j]
            dut.data[j].value = from_signed_8(val)
        
        dut.length.value = tc["length"]
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        max_cycles = 20
        done_found = False
        
        for cycle in range(max_cycles):
            if not is_value_defined(dut.done.value):
                dut._log.warning(f"Case {i+1}: done signal is undefined at cycle {cycle}")
                continue
            
            if dut.done.value == 1:
                done_found = True
                break
            await RisingEdge(dut.clk)
        
        if not done_found:
            raise TestFailure(f"Test Case {i+1} failed: Done signal not asserted within {max_cycles} cycles")
        
        # Check outputs
        if not is_value_defined(dut.result_len.value):
            raise TestFailure(f"Test Case {i+1} failed: result_len is undefined")
        
        actual_len = int(dut.result_len.value)
        expected_len = tc["expected_len"]
        
        if actual_len != expected_len:
            raise TestFailure(f"Test Case {i+1} failed: result_len={actual_len}, expected={expected_len}")
        
        # Check valid mask
        if not is_value_defined(dut.valid_mask.value):
             raise TestFailure(f"Test Case {i+1} failed: valid_mask is undefined")
        
        actual_mask = int(dut.valid_mask.value)
        expected_mask = (1 << expected_len) - 1
        
        if actual_mask != expected_mask:
            raise TestFailure(f"Test Case {i+1} failed: valid_mask={bin(actual_mask)}, expected={bin(expected_mask)}")
            
        # Check result array elements
        # Only check the first 'expected_len' elements. The rest can be anything or 0.
        # However, the prompt implies we track the array content.
        # We will check the first 'expected_len' elements against 'expected_result'.
        
        for k in range(expected_len):
            if not is_value_defined(dut.result[k].value):
                raise TestFailure(f"Test Case {i+1} failed: result[{k}] is undefined")
            
            actual_val = to_signed_8(int(dut.result[k].value))
            expected_val = tc["expected_result"][k]
            
            if actual_val != expected_val:
                raise TestFailure(f"Test Case {i+1} failed: result[{k}]={actual_val}, expected={expected_val}")
        
        dut._log.info(f"Test Case {i+1} passed")
        passed += 1
        
        # Wait a bit before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")