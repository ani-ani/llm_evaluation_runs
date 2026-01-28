import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Include helpers
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

# Fixed-point helpers
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Combinatorial test function
def compute_4pack_stats_python(weights):
    """Compute statistics for 4-pack selection"""
    N = len(weights)
    max_weight = 4 * max(weights)
    min_weight = 4 * min(weights)
    
    # Expected value: each weight appears in (N-1)^3 combinations out of N^3 total
    # But problem defines distinct packs, so we count unique multisets
    # For expected value, we need sum of all distinct pack sums / count
    # However, the example uses E[weight] = sum(weights) * 4 / N
    # This is correct if selection is truly uniform (with replacement)
    expected = sum(weights) * 4 / N
    
    # Count distinct sums: DP over counts of each weight (0 to 4)
    # Since we only care about sums, we can use DP
    max_sum = 4 * max(weights)
    dp = [set() for _ in range(5)]  # dp[k] = set of sums with k selections
    dp[0].add(0)
    
    for w in weights:
        for k in range(4, 0, -1):
            for prev_sum in dp[k-1]:
                dp[k].add(prev_sum + w)
    
    distinct_count = len(dp[4])
    
    return max_weight, min_weight, distinct_count, expected

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_4pack_stats(dut):
    # Check for sequential signals
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clk = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clk.start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1, 2, 4, 7], "Sample 1"),
        ([2, 5, 4], "Sample 2"),
    ]
    
    passed = 0
    failed = 0
    
    for weights, desc in test_cases:
        cocotb.log.info(f"Testing {desc}: weights={weights}")
        
        try:
            N = len(weights)
            exp_max, exp_min, exp_dist, exp_expected = compute_4pack_stats_python(weights)
            
            # Write inputs
            dut.N.value = N
            for i, w in enumerate(weights):
                dut.weights[i].value = clamp_to_width(w, 16)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_seen = False
                for _ in range(500):  # Max cycles
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_seen = True
                        break
                
                if not done_seen:
                    raise TestFailure(f"Done not asserted within 500 cycles")
                
                # Read results
                max_out = int(dut.max_out.value)
                min_out = int(dut.min_out.value)
                distinct_out = int(dut.distinct_out.value)
                expected_out = int(dut.expected_out.value)
            else:
                # Combinatorial
                await Timer(100, units='ns')
                max_out = int(dut.max_out.value)
                min_out = int(dut.min_out.value)
                distinct_out = int(dut.distinct_out.value)
                expected_out = int(dut.expected_out.value)
            
            # Verify max
            if max_out != exp_max:
                raise TestFailure(f"Max mismatch: expected {exp_max}, got {max_out}")
            
            # Verify min
            if min_out != exp_min:
                raise TestFailure(f"Min mismatch: expected {exp_min}, got {min_out}")
            
            # Verify distinct count
            if distinct_out != exp_dist:
                raise TestFailure(f"Distinct count mismatch: expected {exp_dist}, got {distinct_out}")
            
            # Verify expected (allow small error)
            exp_fixed = float_to_fixed(exp_expected, 16)
            # Allow 1 ULP error for fixed-point
            if abs(expected_out - exp_fixed) > 2:
                fixed_float = fixed_to_float(expected_out, 16)
                raise TestFailure(f"Expected weight mismatch: expected {exp_expected:.8f}, got {fixed_float:.8f}")
            
            cocotb.log.info(f"  PASSED: max={max_out}, min={min_out}, distinct={distinct_out}, expected={fixed_to_float(expected_out,16):.8f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed ({passed}/{passed+failed})")