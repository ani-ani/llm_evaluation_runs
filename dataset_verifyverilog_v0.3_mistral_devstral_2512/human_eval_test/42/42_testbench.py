import cocotb
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=200, timeout_unit="ms")
async def test_incr_list(dut):
    """Test the incr_list module with various array lengths"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (len, input_array, expected_output)
    test_cases = [
        (0, [0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]),  # Empty array
        (3, [3, 2, 1, 0, 0, 0, 0, 0], [4, 3, 2, 0, 0, 0, 0, 0]),  # 3 elements
        (9, [5, 2, 5, 2, 3, 3, 9, 0, 123], [6, 3, 6, 3, 4, 4, 10, 1, 124]),  # 9 elements - should wrap
        (1, [255, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0]),  # Overflow test
        (8, [10, 20, 30, 40, 50, 60, 70, 80], [11, 21, 31, 41, 51, 61, 71, 81]),  # Full array
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (length, input_arr, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: len={length}, input={input_arr[:length] if length <= 8 else input_arr[:8]}")
        
        # Load inputs
        if length > 8:
            dut._log.warning(f"Length {length} > 8, truncating to 8")
            length = 8
        
        dut.len.value = length
        for j in range(8):
            dut.arr[j].value = input_arr[j]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with cycle-based timeout
        done_received = False
        max_cycles = 20
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Done signal not received after {max_cycles} cycles")
        
        # Verify results
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Test {i+1}: Valid signal is undefined")
        
        if dut.valid.value != 1:
            raise TestFailure(f"Test {i+1}: Valid signal not high")
        
        # Check first 'length' elements
        all_correct = True
        for j in range(length):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: Result[{j}] is undefined")
            
            actual = int(dut.result[j].value)
            if actual != expected[j]:
                dut._log.error(f"Test {i+1}, Element {j}: expected {expected[j]}, got {actual}")
                all_correct = False
        
        if all_correct:
            passed += 1
            dut._log.info(f"Test case {i+1}: PASSED")
        else:
            raise TestFailure(f"Test case {i+1} failed")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
