import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, MAX_DAYS, CLK_NS, MAX_CYCLES = 2, 100, 10, 2000

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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_days(dut, days, n):
    """Write day array and n to the DUT. day_arr is assumed to be an array of 2-bit signals."""
    for i in range(MAX_DAYS):
        if i < n:
            val = days[i] & 3  # Ensure 2-bit width
            if hasattr(dut, f'day_arr_{i}'):  # Individual port per day
                getattr(dut, f'day_arr_{i}').value = val
            elif hasattr(dut, 'day_arr'):  # Array access
                # Check if it's a list-like access
                try:
                    dut.day_arr[i].value = val
                except (AttributeError, TypeError):
                    # Fallback: assume packed vector or unsupported; skip for now
                    pass
        else:
            if hasattr(dut, f'day_arr_{i}'):
                getattr(dut, f'day_arr_{i}').value = 0
    if has_signal(dut, 'n'):
        dut.n.value = n

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_vacation_dp(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Helper to compute expected answer in Python
    def compute_expected(days, n):
        # Python DP implementation for validation
        INF = 255
        dp = [[0, INF, INF] for _ in range(n+1)]  # dp[0] = [0, INF, INF] (before any day)
        # Actually, dp[0] is initial state: before day 0, all states are 0 rest days
        for i in range(1, n+1):
            day = days[i-1]  # day input for day i
            dp[i][0] = min(dp[i-1][0], dp[i-1][1], dp[i-1][2]) + 1
            dp[i][1] = min(dp[i-1][0], dp[i-1][2]) if (day & 1) else INF
            dp[i][2] = min(dp[i-1][0], dp[i-1][1]) if (day & 2) else INF
        return min(dp[n])

    test_cases = [
        (4, [1,3,2,0], 2, "example 1"),
        (7, [1,3,3,2,1,2,3], 0, "example 2"),
        (2, [2,2], 1, "example 3"),
        (1, [0], 1, "single rest day"),
        (10, [0,0,1,1,0,0,0,0,1,0], 8, "long rest"),
    ]
    passed = failed = 0
    
    for i, (n, days, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}, n={n}, days={days}")
        try:
            await write_days(dut, days, n)
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    # Random test for n=100 (scaled down for speed)
    for r in range(3):
        n = random.randint(1, 20)  # Small n for random test
        days = [random.randint(0, 3) for _ in range(n)]
        exp = compute_expected(days, n)
        cocotb.log.info(f"Random test {r+1}: n={n}, exp={exp}")
        try:
            await write_days(dut, days, n)
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
