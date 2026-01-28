import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for scaling
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    elif v > max_val:
        return max_val
    else:
        return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def compute_expected(arr):
    if not arr:
        return []
    if len(arr) == 1:
        return arr[:]
    
    # Calculate sum of first and last
    arr_len = len(arr)
    sum_val = arr[0] + arr[arr_len - 1]
    
    # Copy to avoid modifying original
    result = arr[:]
    
    if sum_val % 2 == 1:  # Odd: ascending
        result.sort()
    else:  # Even: descending
        result.sort(reverse=True)
    
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for i in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_array(dut, arr_vals):
    """Write array values to dut.arr_in[i] signals"""
    arr_len = len(arr_vals)
    if has_signal(dut, 'len'):
        dut.len.value = arr_len
    else:
        cocotb.log.warning("'len' signal not found, assuming fixed length")
    
    for i in range(ARRAY_SIZE):
        sig_name = f'arr_in_{i}'
        if has_signal(dut, sig_name):
            if i < arr_len:
                val = clamp_to_width(arr_vals[i], DATA_WIDTH)
                getattr(dut, sig_name).value = val
            else:
                getattr(dut, sig_name).value = 0
        else:
            # Try accessing via index if supported
            try:
                if i < arr_len:
                    val = clamp_to_width(arr_vals[i], DATA_WIDTH)
                    dut.arr_in[i].value = val
                else:
                    dut.arr_in[i].value = 0
            except Exception as e:
                raise TestFailure(f"Could not access arr_in[{i}]: {e}")

async def read_output_array(dut):
    """Read result array from dut.result[i] signals"""
    result = []
    for i in range(ARRAY_SIZE):
        sig_name = f'result_{i}'
        if has_signal(dut, sig_name):
            val = getattr(dut, sig_name).value
            if is_value_defined(val):
                result.append(int(val))
            else:
                raise TestFailure(f"Result[{i}] undefined")
        else:
            # Try accessing via index
            try:
                val = dut.result[i].value
                if is_value_defined(val):
                    result.append(int(val))
                else:
                    raise TestFailure(f"Result[{i}] undefined")
            except Exception as e:
                raise TestFailure(f"Could not access result[{i}]: {e}")
    
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sort_array(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Define test cases: (input_array, description)
    test_cases = [
        ([], "empty array"),
        ([5], "single element"),
        ([2, 4, 3, 0, 1, 5], "6 elements, sum odd"),
        ([2, 4, 3, 0, 1, 5, 6], "7 elements, sum even"),
        ([2, 1], "2 elements, sum odd"),
        ([15, 42, 87, 32, 11, 0], "6 elements, sum odd"),
        ([21, 14, 23, 11], "4 elements, sum even"),
        ([100, 200, 50, 150], "4 elements, sum even"),
        ([3, 2, 1, 0], "4 elements, sum odd"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {input_arr}")
        
        try:
            # Compute expected output
            expected = compute_expected(input_arr)
            cocotb.log.info(f"  Expected: {expected}")
            
            # Write input to DUT
            await write_input_array(dut, input_arr)
            
            # Wait for input to stabilize
            await RisingEdge(dut.clk)
            
            # Assert start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read output
            actual = await read_output_array(dut)
            
            # Crop to input length for comparison
            actual_cropped = actual[:len(input_arr)]
            
            cocotb.log.info(f"  Actual: {actual_cropped}")
            
            # Verify
            if actual_cropped != expected:
                raise TestFailure(f"Mismatch: expected {expected}, got {actual_cropped}")
            
            # Verify rest are zeros (optional, good practice)
            if len(input_arr) < ARRAY_SIZE:
                for j in range(len(input_arr), ARRAY_SIZE):
                    if actual[j] != 0:
                        raise TestFailure(f"Extra element {j}: {actual[j]} != 0")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")