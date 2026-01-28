import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 5
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
TARGET = "meow"

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def char_to_bits(c):
    return ord(c) - ord('a')

def edit_distance(s, t):
    m, n = len(s), len(t)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1): dp[i][0] = i
    for j in range(n + 1): dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if s[i-1] == t[j-1]:
                dp[i][j] = dp[i-1][j-1]
            else:
                dp[i][j] = min(dp[i-1][j]+1, dp[i][j-1]+1, dp[i-1][j-1]+1)
    return dp[m][n]

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_meow_factor(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("meow", 0, "Exact match"),
        ("meo", 1, "Insert 'w'"),
        ("mew", 1, "Insert 'o'"),
        ("me", 2, "Insert 'o' and 'w'"),
        ("yarn", 4, "All different"),
        ("", 4, "Empty string"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        for j in range(8):
            port_name = f"char_{j}"
            if has_signal(dut, port_name):
                if j < len(test_str):
                    getattr(dut, port_name).value = char_to_bits(test_str[j])
                else:
                    getattr(dut, port_name).value = 0
        
        dut.len.value = len(test_str)
        await start_computation(dut)
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: Got {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")