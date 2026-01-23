import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=20):
    """Wait for done signal to go high."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_smallest_change(dut):
    """Test smallest_change module with multiple test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    # Initialize all array elements to 0
    for i in range(8):
        getattr(dut, f'arr_{i}').value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_list, expected_result)
    # Arrays are padded to 8 elements with zeros
    test_cases = [
        ([1, 2, 3, 5, 4, 7, 9, 6], 4),
        ([1, 2, 3, 4, 3, 2, 2, 0], 1),
        ([1, 4, 2, 0, 0, 0, 0, 0], 1),
        ([1, 4, 4, 2, 0, 0, 0, 0], 1),
        ([1, 2, 3, 2, 1, 0, 0, 0], 0),
        ([3, 1, 1, 3, 0, 0, 0, 0], 0),
        ([1, 0, 0, 0, 0, 0, 0, 0], 0),
        ([0, 1, 0, 0, 0, 0, 0, 0], 1),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_arr, expected) in enumerate(test_cases):
        # Load array into DUT using individual port access
        getattr(dut, f'arr_0').value = input_arr[0]
        getattr(dut, f'arr_1').value = input_arr[1]
        getattr(dut, f'arr_2').value = input_arr[2]
        getattr(dut, f'arr_3').value = input_arr[3]
        getattr(dut, f'arr_4').value = input_arr[4]
        getattr(dut, f'arr_5').value = input_arr[5]
        getattr(dut, f'arr_6').value = input_arr[6]
        getattr(dut, f'arr_7').value = input_arr[7]
        
        # Wait one cycle for values to stabilize
        await RisingEdge(dut.clk)
        
        # Assert start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        success = await wait_for_done(dut, max_cycles=20)
        
        if not success:
            dut._log.error(f"Test {i}: Done signal not asserted within timeout")
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i}: Result is undefined (X/Z)")
            continue
        
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            passed += 1
            dut._log.info(f"Test {i}: PASSED - Input {input_arr}, Expected {expected}, Got {result}")
        else:
            dut._log.error(f"Test {i}: FAILED - Input {input_arr}, Expected {expected}, Got {result}")
        
        # Wait for done to go low before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
