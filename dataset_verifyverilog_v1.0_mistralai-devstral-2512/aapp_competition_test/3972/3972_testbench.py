import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MOD = 1000000007
CLK_NS = 10
MAX_CYCLES = 15000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def compute_expected(n):
    if n == 1:
        return 1
    if n == 2:
        return 4
    
    dp = [0] * n
    # Base cases derived from the problem logic
    # dp[i] represents count of valid sequences starting from index i to infinity
    # Specific to this problem's constraints
    dp[n-1] = n % MOD
    dp[n-2] = (n * n) % MOD
    
    # Running sum of the relevant window of dp values
    # Window size depends on n, specifically the range [i+3, i+n-1] roughly
    # For simplicity in Python, we use the recurrence found in samples:
    # dp[i] = dp[i+1] + Sum(dp[k] for k in range(i+3, n)) + (n-1)^2 + adjustment
    
    # We need to track the sum of dp values in a sliding window
    # The window for index i includes dp[i+3] ... dp[n-1]
    # Let's use a cumulative sum approach.
    
    # Re-implementation of the logic from the provided Python snippets (specifically the O(N) ones)
    # Using the recurrence: dp[i] = dp[i+1] + (sum of dp[i+d] for d=3 to n-1) + (n-1)^2
    # Actually, the snippets show various forms. Let's stick to a standard DP formulation visible in snippets:
    # One common pattern is:
    # dp[i] = dp[i+1] + sum_{d=3}^{n-1} dp[i+d] + (n-1)^2 + (n-i) [adjustment]
    # But for a correct reference, let's use a known correct relation from the snippets.
    # Example snippet: `dp[i] = dp[i+1] + SA[i-3] + (n-i+2) + (n-1)^2`
    
    # Let's implement the logic from the Python code that matches the problem description best.
    # One of the working snippets logic:
    A = [0] * (n + 1)
    SA = [0] * (n + 1)
    
    A[1] = n
    SA[1] = n
    if n >= 2:
        A[2] = n**2
        SA[2] = n + n**2
    
    for i in range(3, n + 1):
        # A[i] is the answer for size i? Or dp for a specific index?
        # Let's try the logic from the prompt's code snippets which seem to compute dp at index i.
        # Another snippet: `dp = [N] * (N+1)`, `dp[N-1] = N`, `dp[N-2] = N*N`
        # Iteration: `ans = c - dp[i+2] + const`
        
        # Let's implement the logic from the most structured Python snippet in the prompt:
        # It defines `dp[i]` as count for index `i`.
        pass
        
    # Re-evaluating the snippet: "dp[i] := i-th element to drop"
    # Snippet 0 logic:
    # dp = [N] * (N+1)
    # dp[N-1] = N
    # dp[N-2] = N*N
    # c = N * (N+1) + N-1
    # const = (N-1)**2
    # for i in range(N-3, -1, -1):
    #     ans = c - dp[i+2] + const
    #     dp[i] = ans
    #     c = (c + ans - 1) % mod
    
    dp = [0] * (n + 1)
    dp[n-1] = n
    dp[n-2] = n * n
    c_val = n * (n + 1) + n - 1
    const = (n - 1) ** 2
    
    for i in range(n - 3, -1, -1):
        # c_val seems to be maintaining a sum of relevant dp values
        # This logic matches the provided code in the prompt (Snippet 0)
        ans = (c_val - dp[i+2] + const) % MOD
        dp[i] = ans
        c_val = (c_val + ans - 1) % MOD
        
    return dp[0]

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_sequence_count(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        (1, 1),
        (2, 4),
        (3, 15),
        (4, 56),
        (5, 209)
    ]
    
    for n, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, expecting {expected}")
        
        # Check if n_in exists
        if not has_signal(dut, 'n_in'):
             raise TestFailure("Module missing input 'n_in'")
             
        # Drive inputs
        # Ensure width matches spec (10 bits)
        dut.n_in.value = clamp_to_width(n, 10)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=5000)
        
        # Read result
        if not has_signal(dut, 'result'):
             raise TestFailure("Module missing output 'result'")
             
        result_val = int(dut.result.value)
        
        # Verify
        if result_val != expected:
            raise TestFailure(f"For n={n}, expected {expected}, got {result_val}")
        else:
            cocotb.log.info(f"Success: n={n} -> {result_val}")
