import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    # For signed, we need to handle properly, but here we just clamp to positive range
    # The module expects signed outputs, but testbench should use correct range
    max_val = (1 << bits) - 1
    min_val = -(1 << (bits-1))
    return min(max_val, max(min_val, v))

# Constants
DATA_WIDTH = 8
SCALING_FACTOR = 256  # 2^8 for Q8.8
MAX_CYCLES = 1000
CLK_NS = 10

async def write_array(dut, name, vals, width, signed=True):
    """Write values to individual array elements"""
    for i, v in enumerate(vals):
        elem = getattr(dut, f"{name}_{i}", None)
        if elem is None:
            # Try indexed access
            elem = getattr(dut, name)[i]
        if signed:
            # Convert to signed representation
            v_signed = from_signed(v, width) if v < 0 else v
            elem.value = v_signed & ((1 << width) - 1)
        else:
            elem.value = clamp_to_width(v, width)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def compute_expected(nums, dens, length):
    results = []
    for i in range(length):
        num = to_signed(safe_int(nums[i]), DATA_WIDTH)
        den = to_signed(safe_int(dens[i]), DATA_WIDTH)
        if den == 0:
            results.append(0)
        else:
            # Compute scaled result: (num * 256) / den
            # Use floating point for accurate expected value
            expected = (num * 256) / den
            # Round to nearest integer for Q8.8 representation
            results.append(int(round(expected)))
    return results

async def test_div_list(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([4, 5, 6], [1, 2, 3], 3, "Basic integers"),
        ([3, 2], [1, 4], 2, "Fractional results"),
        ([90, 120], [50, 70], 2, "Larger numbers"),
        ([100, 100], [2, 5], 2, "Scaling test"),
    ]
    
    for i, (nums, dens, length, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            for idx in range(length):
                getattr(dut, f'num_{idx}').value = from_signed(nums[idx], DATA_WIDTH)
                getattr(dut, f'den_{idx}').value = from_signed(dens[idx], DATA_WIDTH)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            actual = []
            for idx in range(length):
                res_elem = getattr(dut, f'result_{idx}')
                if not is_value_defined(res_elem.value):
                    raise TestFailure(f"Result element {idx} undefined")
                res_val = to_signed(int(res_elem.value), 16)
                actual.append(res_val)
            
            expected = compute_expected(nums, dens, length)
            
            # Compare with tolerance for division
            for idx, (act, exp) in enumerate(zip(actual, expected)):
                # Allow small rounding difference
                if abs(act - exp) > 1:
                    raise TestFailure(f"Index {idx}: expected {exp}, got {act}")
            
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            raise

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_div_list_basic(dut):
    """Test element-wise division with Q8.8 fixed-point arithmetic"""
    await test_div_list(dut)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_div_list_edge_cases(dut):
    """Test edge cases including zero denominator"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test zero denominator
    nums = [100, 200]
    dens = [0, 10]
    length = 2
    
    for idx in range(length):
        getattr(dut, f'num_{idx}').value = from_signed(nums[idx], DATA_WIDTH)
        getattr(dut, f'den_{idx}').value = from_signed(dens[idx], DATA_WIDTH)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # First element: denominator zero -> result should be 0
    res0 = to_signed(int(getattr(dut, 'result_0').value), 16)
    if res0 != 0:
        raise TestFailure(f"Zero denominator result: expected 0, got {res0}")
    
    # Second element: 200*256/10 = 5120
    res1 = to_signed(int(getattr(dut, 'result_1').value), 16)
    exp = int(200 * 256 / 10)
    if res1 != exp:
        raise TestFailure(f"Second result: expected {exp}, got {res1}")
    
    cocotb.log.info("Edge cases: PASS")
