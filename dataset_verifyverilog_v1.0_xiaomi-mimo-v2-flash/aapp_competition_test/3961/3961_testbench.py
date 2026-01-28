import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MOD = 1000000007
DATA_WIDTH = 32
LEN_WIDTH = 10
P_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 4096

# Helpers
def clamp_to_width(v, width):
    return v & ((1 << width) - 1)

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python Reference DP
def solve_python(n, p_list):
    dp = [0] * (n + 2)  # 1-indexed
    dp[1] = 2
    for i in range(2, n + 1):
        if p_list[i-2] == i:  # p_i == i+1 (since input is 1-indexed, stored in 0-indexed list)
            dp[i] = (dp[i-1] + 2) % MOD
        else:
            # Formula: 2*dp[i-1] - dp[p_i] + 2
            # Note: p_list[i-2] is p_i. The formula uses dp[p_i] where p_i is the room number.
            # If p_i < i, dp[p_i] is already computed.
            p_val = p_list[i-2]
            val = (2 * dp[i-1] - dp[p_val] + 2) % MOD
            dp[i] = val
    return dp[n]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_vasya_maze(dut):
    # Setup clock
    clk = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clk.start())
    await reset_dut(dut)

    # Test cases (n, p_list)
    test_cases = [
        (2, [1, 2]),
        (4, [1, 1, 2, 3]),
        (5, [1, 1, 1, 1, 1]),
        (7, [1, 2, 1, 3, 1, 2, 1]),
        (10, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
    ]

    for n, p_list in test_cases:
        cocotb.log.info(f"Running test for n={n}")
        
        # Compute expected result
        expected = solve_python(n, p_list)
        
        # Load inputs into DUT
        dut.start.value = 1
        dut.len.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for input phase (LOAD state)
        # Send p_i values
        for i in range(n):
            # Wait for DUT to accept input (checking ready signal if exists, else assume ready)
            # If there is no ready, we just pulse valid_in
            dut.valid_in.value = 1
            dut.p_i.value = clamp_to_width(p_list[i], P_WIDTH)
            await RisingEdge(dut.clk)
            
            # If DUT has backpressure (ready), check it here. 
            # Assuming simplest protocol where valid_in is pulsed.
            # If DUT handles one per cycle automatically:
            dut.valid_in.value = 0
            # Small delay or check ready?
            # Let's assume valid_in is a pulse for one cycle per input.
            
        # Compute phase
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"For n={n}, expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Pass: n={n}, result={result}")

    # Additional random tests for robustness
    for _ in range(3):
        n = random.randint(1, 10)
        p_list = [random.randint(1, i+1) for i in range(1, n+1)]
        cocotb.log.info(f"Running random test for n={n}")
        expected = solve_python(n, p_list)
        
        dut.start.value = 1
        dut.len.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for val in p_list:
            dut.valid_in.value = 1
            dut.p_i.value = clamp_to_width(val, P_WIDTH)
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            
        await wait_for_done(dut)
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Random test failed: n={n}, expected {expected}, got {result}")
