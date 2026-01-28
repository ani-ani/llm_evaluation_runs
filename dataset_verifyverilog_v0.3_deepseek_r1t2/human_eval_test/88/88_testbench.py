import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check if a value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to pack array for easier assignment if needed, but we will use element-wise
async def load_array(dut, values):
    """Load values into the dut input array."""
    for i, val in enumerate(values):
        # Check bit width safety (8 bits)
        if val > 255 or val < 0:
            raise ValueError(f"Value {val} out of 8-bit range")
        dut.arr[i].value = val

async def read_array(dut):
    """Read values from the dut output array."""
    result = []
    for i in range(8):
        val = dut.result[i].value
        if not is_value_defined(val):
            raise TestFailure(f"Output result[{i}] is undefined")
        result.append(int(val))
    return result

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_conditional_sorter(dut):
    """Test the conditional sorter module."""
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (input_array, expected_output, description)
    test_cases = [
        # Case 1: Empty-like (using zeros, but we need 8 elements for HDL)
        # Using [0,0,0,0,0,0,0,0] -> sum=0 (even) -> Descending -> still [0,...]
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], "All zeros (even sum)"),
        
        # Case 2: Single element effectively
        ([5, 0, 0, 0, 0, 0, 0, 0], [5, 0, 0, 0, 0, 0, 0, 0], "Single 5 (5+0=5 odd -> Ascend)"),
        
        # Case 3: [2, 4, 3, 0, 1, 5] -> Needs 8 elements. Let's pad.
        # Input: [2, 4, 3, 0, 1, 5, 0, 0]
        # First=2, Last=0. Sum=2 (Even). Descending.
        # Sorted Descending: [5, 4, 3, 2, 1, 0, 0, 0]
        ([2, 4, 3, 0, 1, 5, 0, 0], [5, 4, 3, 2, 1, 0, 0, 0], "Even sum, descending sort"),
        
        # Case 4: [2, 4, 3, 0, 1, 5, 6] -> Pad to [2, 4, 3, 0, 1, 5, 6, 0]
        # First=2, Last=0. Sum=2 (Even). Descending.
        # Input: [2, 4, 3, 0, 1, 5, 6, 0]
        # Sorted Descending: [6, 5, 4, 3, 2, 1, 0, 0]
        ([2, 4, 3, 0, 1, 5, 6, 0], [6, 5, 4, 3, 2, 1, 0, 0], "Even sum, descending sort 2"),
        
        # Case 5: [15, 42, 87, 32, 11, 0] -> Pad to [15, 42, 87, 32, 11, 0, 0, 0]
        # First=15, Last=0. Sum=15 (Odd). Ascending.
        # Input: [15, 42, 87, 32, 11, 0, 0, 0]
        # Sorted Ascending: [0, 0, 0, 11, 15, 32, 42, 87]
        ([15, 42, 87, 32, 11, 0, 0, 0], [0, 0, 0, 11, 15, 32, 42, 87], "Odd sum, ascending sort"),
        
        # Case 6: [21, 14, 23, 11] -> Pad to [21, 14, 23, 11, 0, 0, 0, 0]
        # First=21, Last=0. Sum=21 (Odd). Ascending.
        # Input: [21, 14, 23, 11, 0, 0, 0, 0]
        # Sorted Ascending: [0, 0, 0, 0, 11, 14, 21, 23]
        ([21, 14, 23, 11, 0, 0, 0, 0], [0, 0, 0, 0, 11, 14, 21, 23], "Odd sum, ascending sort 2"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting tests: {total} cases")
    
    for i, (input_arr, expected_arr, desc) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {desc}")
        dut._log.info(f"Input: {input_arr}")
        dut._log.info(f"Expected: {expected_arr}")
        
        # 1. Load Input Array
        await load_array(dut, input_arr)
        
        # 2. Pulse Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for Done with timeout (max ~100 cycles for bubble sort 8 elements)
        max_cycles = 200
        done_found = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
            
        # 4. Read Result
        result_arr = await read_array(dut)
        
        # 5. Verify
        if result_arr == expected_arr:
            dut._log.info(f"Test {i+1} PASSED: {result_arr}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Got {result_arr}, Expected {expected_arr}")
            raise TestFailure(f"Output mismatch for case '{desc}'")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
