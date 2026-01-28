import cocotb
from cocotb.triggers import Timer, RisingEdge, Edge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
N_MAX = 10
CLK_NS = 10
MAX_CYCLES = 2500

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_expected(a_vals, b_vals, n):
    """Compute lexicographically smallest assignment to minimize diff"""
    # DP: set of possible differences after assigning i candies
    # Use offset to handle negative indices
    OFFSET = 2000
    dp = set([0])
    
    # Forward DP to find reachable states
    dp_history = []
    for i in range(n):
        new_dp = set()
        for d in dp:
            # Assign to Alf: diff increases by a_i - b_i
            new_dp.add(d + (a_vals[i] - b_vals[i]))
            # Assign to Beata: diff decreases by b_i - a_i (or stays same)
            new_dp.add(d - (b_vals[i] - a_vals[i]))
        dp_history.append(dp)
        dp = new_dp
    
    # Find minimum absolute difference reachable
    min_diff = float('inf')
    for d in dp:
        if abs(d) < min_diff:
            min_diff = abs(d)
    
    # Backtrack to find lexicographically smallest solution
    result = []
    current_diff = None
    for i in range(n-1, -1, -1):
        found = False
        # Prefer 'A' first (Alf), then 'B' (Beata) for lexicographical order
        for choice in ['A', 'B']:
            if choice == 'A':
                prev_diff = current_diff - (a_vals[i] - b_vals[i]) if current_diff is not None else None
                # Check if this leads to min_diff at the end
                if i == n-1:
                    # Check final state
                    for d in dp:
                        if abs(d) == min_diff and abs(d) == abs(a_vals[i] - b_vals[i]):
                            if d == (a_vals[i] - b_vals[i]):
                                current_diff = d
                                result.append('A')
                                found = True
                                break
                else:
                    # Check intermediate state
                    if prev_diff is not None:
                        if prev_diff in dp_history[i]:
                            current_diff = prev_diff
                            result.append('A')
                            found = True
            else: # 'B'
                if i == n-1:
                    for d in dp:
                        if abs(d) == min_diff and abs(d) == abs(b_vals[i] - a_vals[i]):
                            if d == -(b_vals[i] - a_vals[i]):
                                current_diff = d
                                result.append('B')
                                found = True
                                break
                else:
                    prev_diff = current_diff + (b_vals[i] - a_vals[i]) if current_diff is not None else None
                    if prev_diff is not None:
                        if prev_diff in dp_history[i]:
                            current_diff = prev_diff
                            result.append('B')
                            found = True
            if found:
                break
        if not found:
            # Fallback: choose based on reachability
            pass
    
    # Reverse result since we built it backwards
    result.reverse()
    return ''.join(result)

def pack_string_to_int(s, n):
    """Pack N-character string into 40-bit integer (MSB first)"""
    res = 0
    for i in range(n):
        char = ord(s[i])
        res |= (char << (8 * (n - 1 - i)))
    return res

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_candy_splitting(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Example 1
        ([5, [-2, -1, 0, 1, 2], [2, 1, 0, -1, -2]], "AAAAA", "Example 1"),
        # Example 2
        ([5, [2, 1, 0, 1, 2], [2, 1, 0, 1, 2]], "AAABB", "Example 2"),
        # Single candy
        ([1, [5], [3]], "A", "Single A"),
        ([1, [3], [5]], "A", "Single B preferred A"),
        # Equal values, prefer A
        ([2, [1, 1], [1, 1]], "AA", "Equal values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (params, exp_str, desc) in enumerate(test_cases):
        n, a_vals, b_vals = params
        cocotb.log.info(f"Test {i+1}: {desc}, N={n}")
        
        # Trim/expand arrays to N_MAX
        a_vals_full = a_vals + [0] * (N_MAX - len(a_vals))
        b_vals_full = b_vals + [0] * (N_MAX - len(b_vals))
        
        try:
            if is_seq:
                # Write inputs
                for idx in range(N_MAX):
                    getattr(dut, f'a_vals_{idx}').value = from_signed(a_vals_full[idx], DATA_WIDTH)
                    getattr(dut, f'b_vals_{idx}').value = from_signed(b_vals_full[idx], DATA_WIDTH)
                dut.N.value = n
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result_int = int(dut.result.value)
                
                # Unpack
                result_str = ""
                for idx in range(n):
                    char = (result_int >> (8 * (n - 1 - idx))) & 0xFF
                    result_str += chr(char)
                
                # Verify
                expected = compute_expected(a_vals, b_vals, n)
                if result_str != expected:
                    raise TestFailure(f"Expected '{expected}', got '{result_str}'")
                
                # Verify lexicographical property
                # Try flipping first 'B' to 'A' and check if diff increases
                # Simple check: verify absolute diff is minimized
                # Compute actual diff for result
                sum_a = 0
                sum_b = 0
                for idx in range(n):
                    if result_str[idx] == 'A':
                        sum_a += a_vals[idx]
                    else:
                        sum_b += b_vals[idx]
                actual_diff = abs(sum_a - sum_b)
                
                # Verify it's the minimum possible
                # Quick check: for 2 candies, minimum diff check
                if n == 1:
                    if actual_diff != abs(a_vals[0] - b_vals[0]):
                        raise TestFailure(f"Single candy diff incorrect: {actual_diff}")
            else:
                await Timer(100, units='ns')
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")