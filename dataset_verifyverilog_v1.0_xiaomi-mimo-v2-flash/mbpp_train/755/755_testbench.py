import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 8, 10, 1000

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
    return min((1 << bits) - 1, max(0, v))

def float_to_q8_8(f, frac=128):
    """Convert float to Q8.8 fixed-point (2^7=128 scaling)"""
    return int(f * frac) if f >= 0 else (int(f * frac) & 0xFFFF)

def q8_8_to_float(v, frac=128):
    """Convert Q8.8 to float, handle signed"""
    signed = to_signed(v, 16)
    return signed / frac

def write_array_q8_8(dut, name, values):
    """Write Q8.8 fixed-point values to array of 16-bit inputs"""
    for i in range(ARRAY_SIZE):
        val = float_to_q8_8(values[i] if i < len(values) else 0)
        getattr(dut, f'{name}_{i}').value = clamp_to_width(val, DATA_WIDTH)

def write_valid_mask(dut, values, n):
    """Create valid mask for first n elements"""
    mask = 0
    for i in range(min(n, ARRAY_SIZE)):
        mask |= (1 << i)
    dut.valid_in.value = clamp_to_width(mask, 8)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_second_smallest(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases adapted for Q8.8 and fixed-size arrays
    test_cases = [
        # (input floats, valid count, expected result or None, description)
        ([1.0, 2.0, -8.0, -2.0, 0.0, -2.0], 6, -2.0, "Test 1: integers and duplicates"),
        ([1.0, 1.0, -0.5, 0.0, 2.0, -2.0, -2.0], 7, -0.5, "Test 2: floats and duplicates"),
        ([2.0, 2.0], 2, None, "Test 3: only duplicates"),
        ([2.0, 2.0, 2.0], 3, None, "Test 4: all same"),
        ([5.0, 3.0, 1.0, 9.0, 2.0], 5, 2.0, "Test 5: sorted ascending"),
        ([10.0, 10.0, 5.0, 5.0, 1.0], 5, 5.0, "Test 6: multiple duplicates"),
        ([-1.0, -2.0, -3.0, -4.0], 4, -2.0, "Test 7: all negative"),
    ]
    
    passed = failed = 0
    
    for i, (vals, n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            write_array_q8_8(dut, 'arr', vals)
            write_valid_mask(dut, vals, n)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result_q8_8 = int(dut.result.value)
                result_float = q8_8_to_float(result_q8_8)
                
                # Special case: 0xFFFF means None
                if result_q8_8 == 0xFFFF:
                    result_float = None
                
                # Compare with expected
                if expected is None:
                    if result_float is not None:
                        raise TestFailure(f"Expected None, got {result_float}")
                else:
                    if result_float is None:
                        raise TestFailure(f"Expected {expected}, got None")
                    # Allow small tolerance for Q8.8 rounding
                    tolerance = 0.01
                    if abs(result_float - expected) > tolerance:
                        raise TestFailure(f"Expected {expected}, got {result_float}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")