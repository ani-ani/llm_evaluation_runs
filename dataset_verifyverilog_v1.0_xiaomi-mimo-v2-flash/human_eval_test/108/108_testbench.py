import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
RESULT_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 2000

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def calculate_expected(arr, length):
    count = 0
    for i in range(length):
        num = arr[i]
        if num == 0:
            continue
        
        # Calculate signed digit sum
        abs_num = abs(num)
        temp = abs_num
        abs_sum = 0
        first_digit = 0
        is_first = True
        
        while temp > 0:
            digit = temp % 10
            abs_sum += digit
            if is_first:
                first_digit = digit
                is_first = False
            temp //= 10
            
        if is_first: # Number was 0
            signed_sum = 0
        elif num < 0:
            signed_sum = abs_sum - (2 * first_digit)
        else:
            signed_sum = abs_sum
            
        if signed_sum > 0:
            count += 1
            
    return count

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_count_nums(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases from problem
    test_cases = [
        ([], 0, "Empty array"),
        ([-1, -2, 0], 0, "All non-positive sum"),
        ([1, 1, 2, -2, 3, 4, 5], 6, "Mixed positive"),
        ([1, 100, 98, -7, 1, -1], 4, "Larger numbers"),
        ([-0, 1**0], 1, "Zero and One"),
        ([1], 1, "Single one"),
        ([-1, 11, -11], 1, "Specific negative case"),
        ([12, 23, 34, -45, -56, 0], 5, "Multi-digit cases")
    ]

    passed = 0
    failed = 0

    for idx, (input_list, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx + 1}: {desc} - Input: {input_list}")
        
        # Pad input list to ARRAY_SIZE if necessary, or handle len=0
        # We will assign exactly len elements to the array
        length = len(input_list)
        
        # Assign array elements
        # Note: If the HDL expects a packed array, we might need to adjust, 
        # but the prompt specifies arr[0:15], so individual elements are safer.
        for i in range(length):
            val = input_list[i]
            # Map -128..127 to 0..255 for unsigned assignment, or handle signed
            # Assuming dut.arr[i] is 8-bit logic/vector. 
            # We assign the integer value directly; cocotb will handle conversion if possible,
            # otherwise we might need to convert to binary string.
            # For simplicity, assuming dut.arr[i] accepts integer assignment.
            dut.arr[i].value = val
            
        # Set length
        # Check if 'len' signal exists or if it's part of a struct/valid signal
        if has_signal(dut, 'len'):
            dut.len.value = length
        else:
            # If len is not a signal, maybe it's implicitly known or handled differently.
            # Assuming it exists based on prompt spec.
            pass
        
        # Trigger start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
                
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Small delay between tests
        await Timer(100, units='ns')
        await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
