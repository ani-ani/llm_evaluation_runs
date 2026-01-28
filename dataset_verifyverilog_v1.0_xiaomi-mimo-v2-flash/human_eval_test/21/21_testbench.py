import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Fixed-point Q8.8 constants
DATA_WIDTH = 16
FRAC_BITS = 8
INT_BITS = 8
MAX_VAL = 65535  # 0xFFFF
MIN_VAL = -32768 # 0x8000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    min_val = -(1 << (bits-1))
    return min(max_val, max(min_val, v))

def float_to_q88(f):
    """Convert float to Q8.8 fixed-point"""
    val = int(round(f * (1 << FRAC_BITS)))
    return clamp_to_width(val, DATA_WIDTH)

def q88_to_float(val):
    """Convert Q8.8 to float"""
    if val >= 0:
        return val / (1 << FRAC_BITS)
    else:
        return val / (1 << FRAC_BITS)

# Test values
test_cases = [
    ([2.0, 49.9], [0.0, 1.0], "Two elements ascending"),
    ([100.0, 49.9], [1.0, 0.0], "Two elements descending"),
    ([1.0, 2.0, 3.0, 4.0, 5.0], [0.0, 0.25, 0.5, 0.75, 1.0], "Five elements"),
    ([2.0, 1.0, 5.0, 3.0, 4.0], [0.25, 0.0, 1.0, 0.5, 0.75], "Unordered five"),
    ([12.0, 11.0, 15.0, 13.0, 14.0], [0.25, 0.0, 1.0, 0.5, 0.75], "Another five"),
]

async def write_array(dut, vals):
    """Write array to DUT (element by element)"""
    for i in range(8):
        if i < len(vals):
            val = float_to_q88(vals[i])
            # Handle unpacked array access
            if has_signal(dut, f'arr_in_{i}'):
                getattr(dut, f'arr_in_{i}').value = val
            # Handle packed array
            elif hasattr(dut, 'arr_in'):
                # Could be unpacked or 2D array
                try:
                    dut.arr_in[i].value = val
                except (AttributeError, TypeError):
                    # Skip if array size mismatch
                    pass
        else:
            # Zero out unused elements
            if has_signal(dut, f'arr_in_{i}'):
                getattr(dut, f'arr_in_{i}').value = 0
            elif hasattr(dut, 'arr_in'):
                try:
                    dut.arr_in[i].value = 0
                except (AttributeError, TypeError):
                    pass

def read_array(dut, length):
    """Read array from DUT (element by element)"""
    result = []
    for i in range(length):
        if has_signal(dut, f'arr_out_{i}'):
            val = int(getattr(dut, f'arr_out_{i}').value)
            result.append(q88_to_float(val))
        elif hasattr(dut, 'arr_out'):
            try:
                val = int(dut.arr_out[i].value)
                result.append(q88_to_float(val))
            except (AttributeError, TypeError):
                result.append(0.0)
        else:
            result.append(0.0)
    return result

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rescale_to_unit(dut):
    """Test rescale_to_unit module with various test cases"""
    
    CLK_NS = 10
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    passed = failed = 0
    
    for i, (input_nums, expected_nums, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: {input_nums}")
        cocotb.log.info(f"  Expected: {expected_nums}")
        
        try:
            # Write input array
            await write_array(dut, input_nums)
            
            # Set length if signal exists
            if has_signal(dut, 'len'):
                dut.len.value = len(input_nums)
            
            # Set arr_valid if exists
            if has_signal(dut, 'arr_valid'):
                dut.arr_valid.value = 1
            
            # Start computation
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut)
                else:
                    await Timer(500, units='ns')  # Combinational
            else:
                await Timer(200, units='ns')  # Combinational
            
            # Check if result is valid
            result_valid = True
            if has_signal(dut, 'result_valid'):
                result_valid = int(dut.result_valid.value) == 1
            
            if result_valid:
                # Read result array
                result = read_array(dut, len(input_nums))
                
                # Compare results with tolerance
                tolerance = 0.02  # ~2% tolerance for fixed-point
                for idx, (got, exp) in enumerate(zip(result, expected_nums)):
                    diff = abs(got - exp)
                    if diff > tolerance:
                        raise TestFailure(
                            f"Index {idx}: Expected {exp:.4f}, got {got:.4f}, diff={diff:.4f}"
                        )
                
                cocotb.log.info(f"  Result: {[f'{v:.4f}' for v in result]}")
                passed += 1
            else:
                raise TestFailure("result_valid is 0")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    # Additional test: edge case with min=max (all same values)
    cocotb.log.info("Edge case: all elements same")
    try:
        same_input = [5.0, 5.0, 5.0]
        await write_array(dut, same_input)
        
        if has_signal(dut, 'len'):
            dut.len.value = len(same_input)
        if has_signal(dut, 'arr_valid'):
            dut.arr_valid.value = 1
        
        if is_seq and has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(200, units='ns')
        
        result = read_array(dut, 3)
        # All should be 0.0 when min=max
        for val in result:
            if abs(val) > 0.02:
                raise TestFailure(f"Expected 0.0 for equal values, got {val}")
        
        cocotb.log.info("  Passed: All zeros as expected")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")