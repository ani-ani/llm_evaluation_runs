import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=20):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def write_array_elements(dut, name, values, width):
    """Write array values by individual elements - NOT dut.arr.value = [list]"""
    for i, v in enumerate(values):
        try:
            element = getattr(dut, name)[i]
            element.value = clamp_to_width(v, width)
        except AttributeError:
            # Try alternative naming: arr_0, arr_1, ...
            try:
                element = getattr(dut, f"{name}_{i}")
                element.value = clamp_to_width(v, width)
            except AttributeError:
                raise TestFailure(f"Could not access array {name}[{i}]")

async def test_case(dut, desc, tuple_data, search_val, expected_result):
    """Run a single test case"""
    cocotb.log.info(f"Test: {desc}")
    
    # Write tuple data
    write_array_elements(dut, 'tuple_data', tuple_data, 8)
    
    # Write length and search value
    dut.tuple_len.value = clamp_to_width(len(tuple_data), 5)
    dut.search_value.value = clamp_to_width(search_val, 8)
    
    # Start search
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, max_cycles=20)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal undefined")
    
    result = int(dut.result.value)
    if result != expected_result:
        raise TestFailure(f"Expected result={expected_result}, got {result}")
    
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_tuple_element(dut):
    """Test suite for check_tuple_element module"""
    
    # Setup clock if it exists
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        dut.rst_n.value = 1
        
    # Test cases based on provided examples
    # Note: 'r' = 114, '5' = 53, 3 = 3 in ASCII/numeric
    test_cases = [
        # Test 1: tuple with 'r' at position 2, search for 'r' -> True
        ((119, 51, 114, 101, 115, 111, 117, 114, 99, 101), 114, True, "10 elements, 'r' found"),
        
        # Test 2: same tuple, search for '5' -> False
        ((119, 51, 114, 101, 115, 111, 117, 114, 99, 101), 53, False, "10 elements, '5' not found"),
        
        # Test 3: same tuple, search for 3 -> True
        ((119, 51, 114, 101, 115, 111, 117, 114, 99, 101), 3, True, "10 elements, 3 found"),
        
        # Additional edge cases
        # Empty tuple
        ((), 114, False, "Empty tuple"),
        
        # Single element match
        ((114,), 114, True, "Single element match"),
        
        # Single element no match
        ((119,), 114, False, "Single element no match"),
        
        # Element at last position
        ((119, 51, 114, 101, 115, 111, 117, 114, 99, 101), 101, True, "Element at last position"),
        
        # Element at first position
        ((119, 51, 114, 101, 115, 111, 117, 114, 99, 101), 119, True, "Element at first position"),
        
        # Not found in middle
        ((1, 2, 4, 5), 3, False, "Not found in middle"),
        
        # Found at middle
        ((1, 2, 3, 4), 3, True, "Found at middle"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tuple_data, search_val, expected, desc) in enumerate(test_cases):
        try:
            if is_seq:
                await test_case(dut, f"{i+1}: {desc}", tuple_data, search_val, expected)
            else:
                # Combinational: write inputs and check outputs immediately
                cocotb.log.info(f"Test {i+1}: {desc}")
                write_array_elements(dut, 'tuple_data', tuple_data, 8)
                dut.tuple_len.value = clamp_to_width(len(tuple_data), 5)
                dut.search_value.value = clamp_to_width(search_val, 8)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")