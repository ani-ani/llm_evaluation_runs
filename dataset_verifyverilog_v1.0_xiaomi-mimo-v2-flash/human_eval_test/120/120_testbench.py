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
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def from_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def clamp_signed(v, bits):
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    return min(max_val, max(min_val, v))

# Constants
DATA_WIDTH = 9  # Signed 9-bit
ARRAY_SIZE = 16
K_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 300

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_maximum(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ([-3, -4, 5], 3, [-4, -3, 5], "Example 1"),
        ([4, -4, 4], 2, [4, 4], "Example 2"),
        ([-3, 2, 1, 2, -1, -2, 1], 1, [2], "Example 3"),
        ([123, -123, 20, 0, 1, 2, -3], 3, [2, 20, 123], "Test 4"),
        ([-123, 20, 0, 1, 2, -3], 4, [0, 1, 2, 20], "Test 5"),
        ([5, 15, 0, 3, -13, -8, 0], 7, [-13, -8, 0, 0, 3, 5, 15], "Test 6"),
        ([-1, 0, 2, 5, 3, -10], 2, [3, 5], "Test 7"),
        ([1, 0, 5, -7], 1, [5], "Test 8"),
        ([4, -4], 2, [-4, 4], "Test 9"),
        ([-10, 10], 2, [-10, 10], "Test 10"),
        ([1, 2, 3, -23, 243, -400, 0], 0, [], "Test 11 - k=0")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}, k={k}")
        
        try:
            # Prepare input: extend to ARRAY_SIZE, create valid mask
            input_arr = inp + [0] * (ARRAY_SIZE - len(inp))
            valid_mask = (1 << len(inp)) - 1  # Mask for valid elements
            
            # Set input values
            for j in range(ARRAY_SIZE):
                val = input_arr[j]
                if has_signal(dut, f'arr_{j}'):
                    # Individual port
                    getattr(dut, f'arr_{j}').value = to_signed(clamp_signed(val, DATA_WIDTH), DATA_WIDTH)
                elif has_signal(dut, 'arr'):
                    # Array (sub-elements)
                    if j < len(dut.arr):
                        dut.arr[j].value = to_signed(clamp_signed(val, DATA_WIDTH), DATA_WIDTH)
                elif has_signal(dut, 'arr_valid'):
                    # Packed array (most likely)
                    pass
            
            # Set arr_valid if exists
            if has_signal(dut, 'arr_valid'):
                dut.arr_valid.value = valid_mask
            
            # Set k
            if has_signal(dut, 'k'):
                dut.k.value = k
            
            # Start sequence
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_found = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_found = True
                        break
                
                if not done_found:
                    raise TestFailure(f"Timeout: done not set within {MAX_CYCLES} cycles")
            else:
                await Timer(200, units='ns')
            
            # Read results
            result_values = []
            if has_signal(dut, 'result'):
                # Array result
                for j in range(min(k, ARRAY_SIZE)):
                    if j < len(dut.result):
                        raw_val = int(dut.result[j].value)
                        val = from_signed(raw_val, DATA_WIDTH)
                        result_values.append(val)
            elif has_signal(dut, 'result_0'):
                # Individual ports
                for j in range(min(k, ARRAY_SIZE)):
                    raw_val = int(getattr(dut, f'result_{j}').value)
                    val = from_signed(raw_val, DATA_WIDTH)
                    result_values.append(val)
            
            # Check result_valid mask
            if has_signal(dut, 'result_valid'):
                result_mask = int(dut.result_valid.value)
                expected_mask = (1 << k) - 1 if k > 0 else 0
                if result_mask != expected_mask:
                    raise TestFailure(f"result_valid mismatch: expected {expected_mask:#x}, got {result_mask:#x}")
            
            # Sort result values (they should already be sorted ascending)
            result_values.sort()
            
            # Validate
            if len(result_values) != len(expected):
                raise TestFailure(f"Length mismatch: expected {len(expected)}, got {len(result_values)}")
            
            if k > 0:
                for idx, (got, exp) in enumerate(zip(result_values, expected)):
                    if got != exp:
                        raise TestFailure(f"Value mismatch at {idx}: expected {exp}, got {got}")
            
            cocotb.log.info(f"  PASS: result={result_values}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")