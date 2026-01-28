import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def python_find_min_diff(arr):
    """Reference implementation"""
    if len(arr) < 2:
        return 0
    arr = sorted(arr)
    min_diff = 2**31
    for i in range(len(arr)-1):
        diff = abs(arr[i+1] - arr[i])
        if diff < min_diff:
            min_diff = diff
    return min_diff

async def write_array_elements(dut, vals, width):
    """Write array elements individually"""
    for i in range(MAX_LEN):
        if i < len(vals):
            getattr(dut, f'arr_{i}').value = clamp_to_width(vals[i], width)
        else:
            getattr(dut, f'arr_{i}').value = 0

async def test_one_case(dut, test_num, input_arr, exp_result):
    """Test single case and return True if passed"""
    cocotb.log.info(f"Test {test_num}: arr={input_arr}, expected={exp_result}")
    
    # Write input array
    await write_array_elements(dut, input_arr, DATA_WIDTH)
    
    # Write length
    if has_signal(dut, 'len'):
        dut.len.value = len(input_arr)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, MAX_CYCLES)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    
    # Allow for minor differences if input has duplicates
    if result != exp_result:
        # Check if it's a valid alternative (e.g., 0 for duplicates)
        if exp_result == 0 and result == 0:
            return True
        raise TestFailure(f"Expected {exp_result}, got {result}")
    
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_diff(dut):
    """Main test function for min difference finder"""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([1, 5, 3, 19, 18, 25], 1),
        ([4, 3, 2, 6], 1),
        ([30, 5, 20, 9], 4),
    ]
    
    # Additional edge cases
    edge_cases = [
        ([5, 10], 5),
        ([10, 5], 5),  # Reverse order
        ([1, 2, 3], 1),  # Consecutive
        ([100, 200, 300], 100),  # Equal spacing
        ([5, 5, 5], 0),  # All duplicates
        ([0, 0, 0, 0], 0),  # All zeros
        ([1, 255], 254),  # Max difference
        ([255, 1], 254),  # Max difference reversed
        ([1], 0),  # Single element
        ([0], 0),  # Single zero
        ([], 0),   # Empty (len=0)
    ]
    
    all_tests = test_cases + edge_cases
    passed = 0
    failed = 0
    
    for i, (input_arr, exp_result) in enumerate(all_tests):
        try:
            await test_one_case(dut, i+1, input_arr, exp_result)
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
        
        # Reset between tests
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(all_tests)}")

# Additional stress test with random arrays
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_random_arrays(dut):
    """Test with randomly generated arrays"""
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    random.seed(42)  # For reproducibility
    
    for test_num in range(20):
        # Generate random array length (1-8)
        length = random.randint(1, 8)
        
        # Generate random elements
        input_arr = [random.randint(0, 255) for _ in range(length)]
        
        # Compute expected result
        exp_result = python_find_min_diff(input_arr)
        
        cocotb.log.info(f"Random test {test_num+1}: arr={input_arr}, exp={exp_result}")
        
        try:
            await test_one_case(dut, test_num+1, input_arr, exp_result)
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise TestFailure(f"Random test {test_num+1} failed")
        
        # Reset between tests
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_array(dut):
    """Test with maximum array size (8 elements)"""
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Max array: [255, 200, 150, 100, 50, 25, 10, 0]
    # Sorted: [0, 10, 25, 50, 100, 150, 200, 255]
    # Min diff: 10 (between 0 and 10, or 150 and 200)
    
    input_arr = [255, 200, 150, 100, 50, 25, 10, 0]
    exp_result = python_find_min_diff(input_arr)
    
    cocotb.log.info(f"Max array test: arr={input_arr}, exp={exp_result}")
    
    await test_one_case(dut, 1, input_arr, exp_result)
