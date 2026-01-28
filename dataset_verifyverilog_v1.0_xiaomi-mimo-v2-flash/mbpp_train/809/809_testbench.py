import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

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

async def write_arrays(dut, arr1_vals, arr2_vals, length):
    for i in range(ARRAY_SIZE):
        v1 = arr1_vals[i] if i < length else 0
        v2 = arr2_vals[i] if i < length else 0
        dut.arr1[i].value = clamp_to_width(v1, DATA_WIDTH)
        dut.arr2[i].value = clamp_to_width(v2, DATA_WIDTH)
    if has_signal(dut, 'len'):
        dut.len.value = length

def check_smaller_python(arr1, arr2, length):
    """Reference Python implementation"""
    for i in range(length):
        if arr1[i] <= arr2[i]:
            return False
    return True

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_check_smaller(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        # (arr1, arr2, length, expected_result, description)
        ([1, 2, 3, 0, 0, 0, 0, 0], [2, 3, 4, 0, 0, 0, 0, 0], 3, False, "First tuple smaller (1<2, 2<3, 3<4)"),
        ([4, 5, 6, 0, 0, 0, 0, 0], [3, 4, 5, 0, 0, 0, 0, 0], 3, True, "All elements of arr2 smaller"),
        ([11, 12, 13, 0, 0, 0, 0, 0], [10, 11, 12, 0, 0, 0, 0, 0], 3, True, "Another test case"),
        ([5, 5, 5, 0, 0, 0, 0, 0], [5, 5, 5, 0, 0, 0, 0, 0], 3, False, "Equal elements - should fail"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [0, 1, 2, 3, 4, 5, 6, 7], 8, True, "Full 8-element comparison"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 1, False, "Single element zero equal"),
        ([255, 255, 255, 0, 0, 0, 0, 0], [254, 254, 254, 0, 0, 0, 0, 0], 3, True, "Maximum values"),
        ([100, 100, 100, 100, 0, 0, 0, 0], [101, 101, 101, 101, 0, 0, 0, 0], 4, False, "Mixed case - middle fail"),
        ([5, 10, 15, 0, 0, 0, 0, 0], [4, 9, 16, 0, 0, 0, 0, 0], 3, False, "Last element fails"),
        ([20, 30, 40, 50, 0, 0, 0, 0], [19, 29, 39, 49, 0, 0, 0, 0], 4, True, "All pass"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr1, arr2, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Verify test expectation with Python
            python_result = check_smaller_python(arr1, arr2, length)
            if python_result != expected:
                cocotb.log.error(f"Test case error: Python returned {python_result}, expected {expected}")
                expected = python_result
            
            # Write inputs
            await write_arrays(dut, arr1, arr2, length)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            # Additional check: done signal if present
            if is_seq and has_signal(dut, 'done'):
                if int(dut.done.value) != 1:
                    raise TestFailure("Done signal not asserted when result ready")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Test with varying lengths
    cocotb.log.info("Testing varying lengths...")
    for length in [1, 2, 3, 4, 5, 6, 7, 8]:
        try:
            arr1 = list(range(10, 10 + length))
            arr2 = list(range(9, 9 + length))
            padding = [0] * (8 - length)
            arr1_full = arr1 + padding
            arr2_full = arr2 + padding
            
            python_result = check_smaller_python(arr1_full, arr2_full, length)
            
            await write_arrays(dut, arr1_full, arr2_full, length)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(100, units='ns')
            
            result = int(dut.result.value)
            if result != python_result:
                raise TestFailure(f"Length {length}: Expected {python_result}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  Length {length}: PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  Length {length}: FAIL - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed} tests")
