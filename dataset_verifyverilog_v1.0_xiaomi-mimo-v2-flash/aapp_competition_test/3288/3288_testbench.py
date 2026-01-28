import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Verification Logic (Python) ---
def verify_string(k, s):
    # Double free
    for i in range(len(s)-1):
        if s[i] == s[i+1]: return False
    # k-incremental
    counts = {}
    for c in s:
        counts[c] = counts.get(c, 0) + 1
    if len(counts) != k: return False
    expected_counts = set(range(1, k+1))
    actual_counts = set(counts.values())
    return expected_counts == actual_counts

def count_solutions_py(k):
    # DFS to count all valid strings
    target_len = k * (k + 1) // 2
    counts = [0] * 26
    used_chars = 0
    
    def dfs(idx, prev):
        if idx == target_len:
            # Check if we used exactly k chars and counts match 1..k
            if used_chars != k:
                return 0
            actual_counts = set(counts[c] for c in range(26) if counts[c] > 0)
            if actual_counts == set(range(1, k+1)):
                return 1
            return 0
            
        res = 0
        for c in range(26):
            if c == prev: continue # Double free
            if counts[c] > k: continue # Impossible to fit in 1..k
            if used_chars == k and counts[c] == 0: continue # Already used k chars
            if counts[c] == 0 and used_chars >= k: continue # Cannot introduce new char
            
            counts[c] += 1
            new_used = used_chars if counts[c] > 1 else used_chars + 1
            old_used = used_chars
            used_chars = new_used
            
            res += dfs(idx + 1, c)
            
            used_chars = old_used
            counts[c] -= 1
            
            if res > 10**18: return res # Cap for perf
        return res

    return dfs(0, -1)

# --- Testbench ---
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200000

@cocotb.test(timeout_time=300000, timeout_unit="ms")
async def test_incremental_string(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Helper to run a single test case
    async def run_test(k_val, n_val, expected_str_or_none):
        cocotb.log.info(f"Running test: k={k_val}, n={n_val}")
        
        # Input setup
        dut.k.value = k_val
        dut.n.value = n_val
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=MAX_CYCLES)
        
        # Read result
        if has_signal(dut, 'no_solution') and int(dut.no_solution.value) == 1:
            if expected_str_or_none is not None:
                raise TestFailure(f"Expected solution for k={k_val}, n={n_val}, but got no_solution flag")
            cocotb.log.info(f"Correctly identified no solution for k={k_val}, n={n_val}")
            return
            
        if expected_str_or_none is None:
            raise TestFailure(f"Expected no solution for k={k_val}, n={n_val}, but got a result")
            
        # Read string from output signals
        # We assume the output is streamed out over several cycles
        # The testbench needs to read while result_valid or done is high
        
        collected_string = ""
        max_read_cycles = 400
        
        for _ in range(max_read_cycles):
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                char_val = int(dut.result_char.value)
                collected_string += chr(ord('a') + char_val)
            
            if is_value_defined(dut.finished.value) and int(dut.finished.value) == 1:
                break
                
            await RisingEdge(dut.clk)
            
        if collected_string != expected_str_or_none:
            raise TestFailure(f"String mismatch. Exp: {expected_str_or_none}, Got: {collected_string}")
            
        cocotb.log.info(f"Success: {collected_string}")

    # --- Test Cases ---
    
    # Case 1: k=2, n=650 (zyz)
    # Python logic verification
    # Total solutions for k=2? 
    # Length 3. 1 char once, 1 char twice. 
    # abc pattern. a b a. 
    # Chosen: x, y. 
    # Strings: x y x (x once, y twice) or y x y (y once, x twice).
    # Wait, k=2. One char 1 time, one char 2 times. Length 3.
    # Sequence: A B A (A count 2, B count 1) or B A B (B count 2, A count 1).
    # 26 choices for the '2' count char, 25 for the '1' count char.
    # Total = 26 * 25 = 650.
    # So n=650 is the last one.
    # Lex order: 
    # a b a (a is 2, b is 1)
    # a c a
    # ...
    # z y z (z is 2, y is 1)
    await run_test(2, 650, "zyz")
    
    # Case 2: k=2, n=651 (None)
    await run_test(2, 651, None)
    
    # Case 3: k=5, n=12345678901234
    # This requires a complex count. 
    # We'll rely on the HDL logic to match the Python logic (which we trust for verification).
    # We need to compute the expected output for this case to verify.
    # Due to the complexity of counting for k=5, we will rely on a pre-computed value or skip if not provided.
    # The prompt example provided "yuzczuyuyuzuyci".
    # We will verify this.
    await run_test(5, 12345678901234, "yuzczuyuyuzuyci")
