import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
MAX_CANDIDATES = 8
MAX_LEVEL = 16
MAX_COUNT = 8
CLK_PERIOD_NS = 10

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (signed)."""
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    return max(min_val, min(max_val, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def compute_expected(n, l, s, c):
    """Compute expected profit using Python DP (scaled version)."""
    MAX_LEVEL = 16
    MAX_COUNT = 8
    # Initialize DP table
    dp = [[-10**9] * (MAX_COUNT+1) for _ in range(MAX_LEVEL)]
    for i in range(MAX_LEVEL):
        dp[i][0] = 0
    
    # Process candidates from last to first
    for i in range(n-1, -1, -1):
        a = l[i] - 1  # convert to 0-indexed level
        cost = s[i]
        for j in range(MAX_COUNT, -1, -1):
            if dp[a][j] == -10**9:
                continue
            new_count = j + 1
            if new_count > MAX_COUNT:
                continue
            new_value = dp[a][j] - cost + c[a]
            if new_value > dp[a][new_count]:
                dp[a][new_count] = new_value
                # Propagate fights
                x = a
                w = new_count
                val = new_value
                while w >= 2 and x < MAX_LEVEL-1:
                    next_count = w // 2
                    next_val = val + next_count * c[x+1]
                    if next_val > dp[x+1][next_count]:
                        dp[x+1][next_count] = next_val
                        x += 1
                        w = next_count
                        val = next_val
                    else:
                        break
    
    # Find max profit with count 0 or 1
    max_profit = 0
    for i in range(MAX_LEVEL):
        max_profit = max(max_profit, dp[i][0], dp[i][1])
    return max_profit

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_profit_maximizer(dut):
    """Test the profit maximizer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases (scaled down)
    test_cases = [
        {
            "n": 5,
            "l": [4, 3, 1, 2, 1],
            "s": [1, 2, 1, 2, 1],
            "c": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
            "expected": 6
        },
        {
            "n": 2,
            "l": [1, 2],
            "s": [0, 0],
            "c": [2, 1, -100, -100, -100, -100, -100, -100, -100, -100, -100, -100, -100, -100, -100, -100],
            "expected": 2
        },
        {
            "n": 5,
            "l": [4, 3, 2, 1, 1],
            "s": [0, 2, 6, 7, 4],
            "c": [12, 12, 12, 6, -3, -5, 3, 10, -4, 0, 0, 0, 0, 0, 0, 0],
            "expected": 62
        }
    ]
    
    for test_idx, test in enumerate(test_cases):
        dut._log.info(f"Running test case {test_idx+1}: {test['expected']}")
        
        # Prepare inputs
        n = test['n']
        l = test['l']
        s = test['s']
        c = test['c']
        
        # Fill candidate ports
        for i in range(8):
            if i < n:
                # Clamp values to signal widths
                level_val = clamp_to_width(l[i], 4)
                cost_val = clamp_to_width(s[i], 16)
            else:
                level_val = 0
                cost_val = 0
            
            # Set candidate ports
            if has_signal(dut, f'candidate_level{i}'):
                getattr(dut, f'candidate_level{i}').value = level_val
            if has_signal(dut, f'candidate_cost{i}'):
                getattr(dut, f'candidate_cost{i}').value = cost_val
        
        # Fill profit ports
        for i in range(16):
            profit_val = clamp_to_width(c[i], 16)
            if has_signal(dut, f'profit{i}'):
                getattr(dut, f'profit{i}').value = profit_val
        
        # Set num_candidates
        dut.num_candidates.value = n
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=5000)
        
        # Read result
        if not is_value_defined(dut.max_profit.value):
            raise TestFailure(f"Test {test_idx+1}: max_profit is undefined (X/Z)")
        
        result = int(dut.max_profit.value)
        expected = test['expected']
        
        if result != expected:
            raise TestFailure(f"Test {test_idx+1}: expected {expected}, got {result}")
        
        dut._log.info(f"Test {test_idx+1} passed: {result}")
        
        # Wait a few cycles before next test
        await Timer(100, units='ns')
        await reset_dut(dut, cycles=2)
    
    dut._log.info("All tests passed!")