import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Python reference implementation for verification
def python_ref(n, l, r):
    if n <= 1:
        return n if l == r and l == 1 else 0
    
    # Calculate total length of S(n)
    # Length L(n) = 2*L(n/2) + 1
    # For n > 0, L(n) = 2^(bit_length(n)) - 1
    # However, the sequence structure is strictly binary from n's bits
    # Let's use the recursive logic directly for correctness in testbench
    
    def get_len(x):
        if x <= 1: return 1
        return 2 * get_len(x // 2) + 1
    
    def count_ones(x, ql, qr, sl, sr):
        if ql > qr or sl > sr:
            return 0
        if ql == sl and qr == sr:
            if x <= 1: return x
            # Optimization: full range match means count all ones in S(x)
            def total_ones(val):
                if val <= 1: return val
                return 2 * total_ones(val // 2) + (val % 2)
            return total_ones(x)
        
        if x <= 1:
            # Base case, should only be reached if partial match on size 1
            return x if (ql <= sl and qr >= sr) else 0
            
        mid = (sl + sr) // 2
        res = 0
        # Center
        if ql <= mid <= qr:
            res += (x % 2)
        # Left: range [sl, mid-1], value x//2
        if ql <= mid - 1:
            res += count_ones(x // 2, ql, min(qr, mid - 1), sl, mid - 1)
        # Right: range [mid+1, sr], value x//2
        if qr >= mid + 1:
            res += count_ones(x // 2, max(ql, mid + 1), qr, mid + 1, sr)
        return res
        
    total_len = get_len(n)
    return count_ones(n, l, r, 1, total_len)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_abacaba_count(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.n.value = 0
        dut.l.value = 0
        dut.r.value = 0
        
        for _ in range(5):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    test_cases = [
        (7, 2, 5, 4),       # Example 1
        (10, 3, 10, 5),     # Example 2
        (3, 2, 3, 2),       # Manual check: S(3) = [1,1,1], positions 2,3 are 1s
        (56, 18, 40, 20),   # From dataset
        (0, 1, 1, 0),       # Edge case: n=0
        (1, 1, 1, 1),       # Edge case: n=1
        (2, 2, 2, 0),       # S(2) = [0,0,0], pos 2 is 0
    ]

    passed = 0
    failed = 0

    for i, (n, l, r, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, l={l}, r={r}")
        
        # Verify with Python ref first (sanity check)
        py_res = python_ref(n, l, r)
        if py_res != expected:
            cocotb.log.error(f"Python ref failed: expected {expected}, got {py_res}")
            # continue # Skip if ref is wrong (unlikely)

        # Send inputs
        dut.n.value = clamp_to_width(n, 32)
        dut.l.value = clamp_to_width(l, 16)
        dut.r.value = clamp_to_width(r, 16)
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_seen = False
        for _ in range(2000): # Max cycles
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            cocotb.log.error(f"Test {i+1} TIMEOUT")
            failed += 1
            continue
            
        # Read result
        if not has_signal(dut, 'result'):
            cocotb.log.error("Result signal missing")
            failed += 1
            continue
            
        res = int(dut.result.value)
        if res != expected:
            cocotb.log.error(f"FAIL: n={n}, l={l}, r={r}. Expected {expected}, got {res}")
            failed += 1
        else:
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")
