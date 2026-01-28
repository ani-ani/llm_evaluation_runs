import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
N_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 100
MOD = 1000000007

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fence_painting(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Python reference implementation
    def count_no_of_ways_py(n, k):
        if n == 0: return 0
        if n == 1: return k % MOD
        if n == 2: return (k * k) % MOD
        dp_prev = k * k % MOD  # dp[2]
        dp_curr = k % MOD      # dp[1] - wait, logic check: loop starts at 3
        # Correction: Recurrence is dp[i] = (k-1)*(dp[i-1]+dp[i-2])
        # dp[1] = k
        # dp[2] = k*k
        # dp[3] = (k-1)*(dp[2]+dp[1])
        
        prev2 = k              # dp[1]
        prev1 = (k * k) % MOD  # dp[2]
        
        if n == 1: return prev2
        if n == 2: return prev1
        
        for i in range(3, n + 1):
            curr = ((k - 1) * (prev1 + prev2)) % MOD
            prev2 = prev1
            prev1 = curr
        return prev1

    test_cases = [
        (1, 5, 5, "n=1 base case"),
        (2, 4, 16, "n=2 base case"),
        (3, 2, 6, "n=3 recurrence"),
        (4, 4, 228, "n=4 recurrence"),
        (5, 3, 60, "n=5"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, k={k})")
        try:
            # Drive inputs
            dut.n.value = n
            dut.k.value = k
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
            # Reset for next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")