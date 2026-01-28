import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    if val < 0:
        return (1 << bits) + val
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

# Constants
N = 8
VAL_BITS = 8
K_BITS = 9
RESULT_BITS = 32

# Python Reference for Scaled Values
def solve_python(A, B, K):
    d = [abs(a - b) for a, b in zip(A, B)]
    for _ in range(K):
        max_val = max(d)
        idx = d.index(max_val)
        if max_val == 0:
            d[idx] = 1
        else:
            d[idx] -= 1
    return sum(x * x for x in d)

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_error(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Cases
    # Scaling factor: Map range [-500, 500] to [-128, 127] approximately
    # Input vals: -128 to 127 (8-bit signed)
    test_vectors = [
        ([1, 2], [2, 3], 0, 2),       # d=[1,1], K=0 -> 1+1=2
        ([1, 2], [2, 2], 1, 0),       # d=[1,0], K=1 -> [0,0] -> 0
        ([3, 4], [14, 4], 12, 1),     # d=[11,0], K=12 -> [0,1] (roughly) -> 1
        ([0, 0], [0, 0], 5, 5),       # d=[0,0], K=5 -> [1,0] or [0,1] -> 1+0=1 (Wait, python logic: 0->1 if forced)
        # Actually, let's look at inputs: 2 0 1 ... 
        # Input: 2 0 1 
        # 1 2 
        # 2 2
        # Diff: 1, 0. K=1. Max is 1. Decrement to 0. d=[0,0]. Sum=0. Matches Output 0.
    ]

    # Scaled Inputs for HDL (8-bit signed)
    # Values must fit in -128 to 127
    scaled_tests = []
    for A, B, K, expected in test_vectors:
        # Clamp inputs to 8-bit signed range
        A_scaled = [clamp_to_width(to_signed(x, VAL_BITS), VAL_BITS) for x in A]
        B_scaled = [clamp_to_width(to_signed(x, VAL_BITS), VAL_BITS) for x in B]
        # K fits in 9 bits (0-511)
        K_scaled = K
        
        # Compute expected based on scaled inputs (same logic as Python)
        # Python uses abs diff, so signed->unsigned conversion is implicit in math
        # We need to reverse the sign extension for abs calculation if we want exact match
        # Or simpler: treat the 8-bit value as the actual value.
        # Since we passed 1, 2 etc directly, and clamped, they are correct.
        # Just ensure Python logic matches HDL logic on these clamped values.
        expected_scaled = solve_python([from_signed(x, VAL_BITS) for x in A_scaled], 
                                       [from_signed(x, VAL_BITS) for x in B_scaled], 
                                       K_scaled)
        scaled_tests.append((A_scaled, B_scaled, K_scaled, expected_scaled))

    passed = 0
    failed = 0

    for i, (A_vals, B_vals, K_val, exp_val) in enumerate(scaled_tests):
        cocotb.log.info(f"Test {i+1}: A={A_vals}, B={B_vals}, K={K_val}, Exp={exp_val}")
        
        # Input Phase
        for j in range(N):
            getattr(dut, f'A_in_{j}').value = A_vals[j]
            getattr(dut, f'B_in_{j}').value = B_vals[j]
        dut.K_in.value = K_val
        
        # Start Pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=1000)
            
            # Read Result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != exp_val:
                raise TestFailure(f"Expected {exp_val}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(scaled_tests)}")
