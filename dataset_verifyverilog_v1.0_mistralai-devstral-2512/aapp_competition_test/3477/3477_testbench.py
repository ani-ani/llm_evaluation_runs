import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 300

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(cycles * CLK_NS, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(CLK_NS, units='ns')

async def write_k_array(dut, values):
    # Clamp and write to k[0]...k[7]
    for i in range(8):
        val = values[i] if i < len(values) else 0
        getattr(dut, f'k_{i}').value = clamp_to_width(val, DATA_WIDTH)

async def compute_expected(values, m):
    # Compute exact floating point result in Python
    # values: list of k_i for i=0..7
    n = 8
    # Prefix sums
    sum_k = [0]*(n+1)
    sum_w = [0]*(n+1)
    for i in range(n):
        sum_k[i+1] = sum_k[i] + values[i]
        sum_w[i+1] = sum_w[i] + i * values[i]
    
    INF = 1e18
    dp = [[INF]*(m+1) for _ in range(n+1)]
    dp[0][0] = 0
    
    for i in range(1, n+1):
        for j in range(1, min(i, m) + 1):
            for t in range(j-1, i):
                delta_k = sum_k[i] - sum_k[t]
                delta_w = sum_w[i] - sum_w[t]
                if delta_k == 0:
                    cost = 0
                else:
                    # cost = (delta_w^2) / delta_k
                    cost = (delta_w * delta_w) / delta_k
                if dp[t][j-1] + cost < dp[i][j]:
                    dp[i][j] = dp[t][j-1] + cost
    return dp[n][m]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_xray(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases adapted for n=8 (padded)
    # Case 1: Original example (padded)
    # n=3, m=2, k=[3,1,1] -> padded to 8 bins
    k1 = [3, 1, 1, 0, 0, 0, 0, 0]
    m1 = 2
    exp1 = 0.5
    
    # Case 2: Second example
    # n=5, m=2, k=[8,0,5,13,2] -> padded to 8 bins
    k2 = [8, 0, 5, 13, 2, 0, 0, 0]
    m2 = 2
    exp2 = 6.55
    
    # Case 3: m=1 (all bins one cluster)
    k3 = [10, 10, 10, 10, 0, 0, 0, 0]
    m3 = 1
    exp3 = await compute_expected(k3, 1)
    
    # Case 4: m=3
    k4 = [5, 5, 0, 0, 5, 5, 0, 0]
    m4 = 3
    exp4 = await compute_expected(k4, 3)

    test_cases = [
        (k1, m1, exp1, "Example 1"),
        (k2, m2, exp2, "Example 2"),
        (k3, m3, exp3, "Single cluster"),
        (k4, m4, exp4, "Three clusters")
    ]
    
    passed = 0
    failed = 0
    
    for i, (k_vals, m_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_k_array(dut, k_vals)
            dut.m.value = m_val
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            # Read result (Q8.8 fixed point)
            raw_result = int(dut.result.value)
            # Convert Q8.8 to float
            # If signed, handle it (should be unsigned for cost)
            result_float = raw_result / 256.0
            
            # Check with tolerance
            if abs(result_float - expected) > 0.01:
                raise TestFailure(f"Expected {expected:.4f}, got {result_float:.4f}")
            
            passed += 1
            cocotb.log.info(f"PASS: Got {result_float:.4f}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")
