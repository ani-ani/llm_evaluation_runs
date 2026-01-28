import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions from specification
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
    if v > max_val:
        return max_val
    elif v < min_val:
        return min_val
    else:
        return v

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_values_array(dut, values, width=DATA_WIDTH):
    """Write values to the array ports"""
    for i in range(min(len(values), ARRAY_SIZE)):
        val = clamp_to_width(values[i], width)
        if has_signal(dut, f'values_{i}'):
            getattr(dut, f'values_{i}').value = val
        elif has_signal(dut, 'values'):
            dut.values[i].value = val

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_value_equal(dut):
    """Test checking if all dictionary values equal a target"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from Python specification
    # Note: Keys are ignored, only values matter
    test_cases = [
        # (values, target, expected_result, description)
        ([12, 12, 12, 12], 12, True, "All equal to target"),
        ([12, 12, 12, 12], 10, False, "Values not equal to target"),
        ([12, 12, 12, 12], 5, False, "Values not equal to target"),
        ([0, 0, 0, 0], 0, True, "All zeros"),
        ([1, 1, 1, 1], 1, True, "All ones"),
        ([1, 2, 1, 1], 1, False, "Mixed values"),
        ([-5, -5, -5, -5], -5, True, "All negative equal"),
        ([-5, 5, -5, -5], -5, False, "Mixed with negative"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (vals, target, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Extend values to 16 elements with same value
            extended_vals = vals * (ARRAY_SIZE // len(vals)) if len(vals) < ARRAY_SIZE else vals[:ARRAY_SIZE]
            
            # Set values and target
            await write_values_array(dut, extended_vals, DATA_WIDTH)
            dut.target.value = clamp_to_width(target, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")