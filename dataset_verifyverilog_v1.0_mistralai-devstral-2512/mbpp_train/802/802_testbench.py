import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def write_array(dut, arr, len_val, width=8):
    # Write array elements as individual signals
    for i in range(8):
        val = arr[i] if i < len(arr) else 0
        signal_name = f"arr_{i}"
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(val, width)
        else:
            raise TestFailure(f"Signal {signal_name} not found")
    
    # Write length
    if has_signal(dut, 'len'):
        dut.len.value = clamp_to_width(len_val, 4)
    else:
        raise TestFailure("Signal 'len' not found")

async def compute_rotation(arr):
    """Python reference implementation"""
    for i in range(1, len(arr)):
        if arr[i] < arr[i - 1]:
            return i
    return 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_rotation(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([3, 2, 1], 3, 1, "[3,2,1] -> 1 rotation"),
        ([4, 5, 1, 2, 3], 5, 2, "[4,5,1,2,3] -> 2 rotations"),
        ([7, 8, 9, 1, 2, 3], 6, 3, "[7,8,9,1,2,3] -> 3 rotations"),
        ([1, 2, 3], 3, 0, "[1,2,3] -> 0 rotations (sorted)"),
        ([1, 3, 2], 3, 2, "[1,3,2] -> 2 rotations"),
        ([1], 1, 0, "[1] -> single element"),
        ([2, 1], 2, 1, "[2,1] -> 1 rotation (length 2)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, arr_len, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_array(dut, arr, arr_len, 8)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: Result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    cocotb.log.info(f"\n=== Results: {passed} passed, {failed} failed ===")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# Additional comprehensive tests
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_comprehensive_rotation(dut):
    """Test more edge cases and random inputs"""
    
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Additional test cases
    test_cases = [
        # Rotation at start
        ([2, 1, 3, 4, 5], 5, 1, "Rotation at position 1"),
        # Rotation in middle
        ([4, 5, 6, 7, 1, 2, 3], 7, 4, "Rotation in middle"),
        # Full rotation (last element smaller than first)
        ([2, 3, 4, 5, 1], 5, 4, "Full rotation (element 4 to 0)"),
        # Already sorted with duplicates (but problem says distinct)
        # ([1, 2, 2, 3], 4, 0, "Sorted with duplicates"),
        # Empty-like (but len=0 not tested per problem)
    ]
    
    for i, (arr, arr_len, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await write_array(dut, arr, arr_len, 8)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
        
        await Timer(10, units='ns')
