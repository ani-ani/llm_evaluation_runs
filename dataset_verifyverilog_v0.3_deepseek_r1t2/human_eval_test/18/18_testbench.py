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

async def wait_for_done(dut, timeout_cycles=20):
    """Wait for done signal to go high."""
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return cycle
    raise TestFailure(f"Timeout: done not asserted after {timeout_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_substring_matcher(dut):
    """Test substring matching with overlapping cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.main_len.value = 0
    dut.sub_len.value = 0
    
    # Initialize arrays
    for i in range(8):
        dut.main_str[i].value = 0
        dut.sub_str[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to convert string to ASCII and load into array
    def load_string(str_val, arr_handle, length):
        for i in range(8):
            if i < len(str_val):
                arr_handle[i].value = ord(str_val[i])
            else:
                arr_handle[i].value = 0
    
    # Test cases: (main_str, sub_str, expected_count, test_name)
    test_cases = [
        ('', 'x', 0, "empty_main"),
        ('x', 'x', 1, "single_char_match"),
        ('xyxyxyx', 'x', 4, "multiple_single_char"),
        ('aaa', 'a', 3, "overlapping_aaa"),
        ('aaaa', 'aa', 3, "overlapping_aaaa"),
        ('cacacacac', 'cac', 4, "cac_repeated"),
        ('john doe', 'john', 1, "john_doe"),
        ('aaaa', 'aaaa', 1, "full_match"),
        ('aaaa', 'b', 0, "no_match"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for main_str, sub_str, expected, name in test_cases:
        dut._log.info(f"Test {name}: main='{main_str}', sub='{sub_str}'")
        
        # Load strings
        load_string(main_str, dut.main_str, len(main_str))
        load_string(sub_str, dut.sub_str, len(sub_str))
        
        # Set lengths
        dut.main_len.value = len(main_str)
        dut.sub_len.value = len(sub_str)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, timeout_cycles=15)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {name}: result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {name}: expected {expected}, got {result}")
        
        dut._log.info(f"Test {name}: PASSED (result={result})")
        passed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
