import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on scaled problem
DATA_WIDTH = 8
ARRAY_SIZE = 16
MAX_K = 4
CLK_NS = 10
MAX_CYCLES = 10000

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
    # For signed, clamp to signed range
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    if v > max_val:
        return max_val
    elif v < min_val:
        return min_val
    return v

# Reference Python solution to compute expected values
def reference_solution(arr, k):
    """Reference implementation for validation."""
    n = len(arr)
    best = -10**9  # Minimum possible sum
    for l in range(n):
        for r in range(l, n):
            # Extract subarray and outside elements
            inside = sorted(arr[l:r+1])
            outside = sorted(arr[:l] + arr[r+1:], reverse=True)
            # Perform up to k swaps
            cur_sum = sum(arr[l:r+1])
            swaps = 0
            while swaps < k and swaps < len(inside) and swaps < len(outside):
                if outside[swaps] > inside[swaps]:
                    cur_sum += outside[swaps] - inside[swaps]
                    swaps += 1
                else:
                    break
            best = max(best, cur_sum)
    return best

async def write_array(dut, name, vals, width):
    """Write array elements individually to avoid list assignment issues."""
    for i, v in enumerate(vals):
        # For packed arrays or individual signals
        if hasattr(dut, name) and hasattr(getattr(dut, name), '__getitem__'):
            getattr(dut, name)[i].value = clamp_to_width(v, width)
        else:
            # Try individual signals: arr_0, arr_1, ...
            sig_name = f"{name}_{i}"
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = clamp_to_width(v, width)
            else:
                raise ValueError(f"Signal {sig_name} not found")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_subarray_with_swaps(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test cases: (input_array, k_value, expected_result)
    test_cases = [
        ([10, -1, 2, 2, 2, 2, 2, 2, -1, 10, 0, 0, 0, 0, 0, 0], 2, 32),  # Example 1
        ([-1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4, -1),  # Example 2
        ([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], 2, 16),  # All positive
        ([-5, -3, -2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], 3, -2),  # All negative
        ([5, -2, 3, -1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1, 6),  # Mixed
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, k_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input={input_arr[:10]}..., k={k_val}, Expected={expected}")
        
        try:
            # Write input array
            write_array(dut, 'arr', input_arr, DATA_WIDTH)
            
            # Write k value
            if has_signal(dut, 'k'):
                dut.k.value = clamp_to_width(k_val, 4)
            else:
                raise TestFailure("Signal 'k' not found")
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=5000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            # Convert to signed for comparison
            result_signed = to_signed(result, 16) if result >= (1 << 15) else result
            
            if result_signed != expected:
                raise TestFailure(f"Expected {expected}, got {result_signed}")
            
            passed += 1
            
            # Reset before next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            await reset_dut(dut)  # Reset on failure too
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
