import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 10000

# Helper functions
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
    return min((1 << bits) - 1, max(0, int(v)))

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (clamp_to_width(v, bits) & ((1<<bits)-1)) << (i*bits)
    return r

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def python_solution(N, L, a, c):
    # Compute total bags and price
    total_bags = sum(a)
    total_price = sum(c)
    
    # Scale for fixed-point (Q16.16)
    SCALE = 1 << 16
    
    min_product = None
    
    # Try all partitions where store1 has exactly L bags
    # Use DP to find achievable (bags, price) pairs
    # Since sum(a) ≤ 500, we can use boolean DP
    max_bags = total_bags
    
    # dp[bags] = minimum price achievable
    INF = 1 << 30
    dp1 = [INF] * (max_bags + 1)
    dp1[0] = 0
    
    for i in range(N):
        # Reverse for 0/1 knapsack
        for bags in range(max_bags, a[i]-1, -1):
            if dp1[bags - a[i]] != INF:
                dp1[bags] = min(dp1[bags], dp1[bags - a[i]] + c[i])
    
    # Check partitions where store1 has exactly L bags
    if L <= max_bags and dp1[L] != INF:
        bags1 = L
        price1 = dp1[L]
        bags2 = total_bags - bags1
        price2 = total_price - price1
        
        if bags1 > 0 and bags2 > 0:
            p1 = price1 / bags1  # Average price in store 1
            p2 = price2 / bags2  # Average price in store 2
            product = p1 * p2
            if min_product is None or product < min_product:
                min_product = product
    
    # Try partitions where store2 has exactly L bags
    # This is symmetric: store1 has N-L bags, store2 has L bags
    # So we need to find achievable price for N-L bags
    if N - L <= max_bags and dp1[N - L] != INF:
        bags2 = N - L  # Wait, this is wrong. Let's recalculate.
        # Actually, if store2 has exactly L bags, then store1 has total_bags - L bags
        # We need price for total_bags - L bags
        pass
    
    # Let's redo: we need to check all partitions
    # Actually, the constraint is "at least one store must have exactly L bags"
    # This means either store1 = L or store2 = L (or both if total_bags = 2*L)
    
    # Re-run DP for all achievable pairs
    dp = [[INF] * (max_bags + 1) for _ in range(N + 1)]
    dp[0][0] = 0
    
    for i in range(N):
        for count in range(i, -1, -1):
            for bags in range(max_bags, a[i]-1, -1):
                if dp[count][bags - a[i]] != INF:
                    dp[count+1][bags] = min(dp[count+1][bags], dp[count][bags - a[i]] + c[i])
    
    # Check all valid partitions
    for bags1 in range(1, max_bags):
        price1 = dp[...][bags1]  # We need to know which items selected
        # Actually, we need the minimum price for each bag count
        # Let's use simpler DP: dp[bags] = min price
        pass
    
    # Simpler approach: try all subsets (2^N, N=16 is 65536, feasible)
    min_product = None
    for mask in range(1 << N):
        bags1 = sum(a[i] for i in range(N) if mask & (1 << i))
        price1 = sum(c[i] for i in range(N) if mask & (1 << i))
        bags2 = total_bags - bags1
        price2 = total_price - price1
        
        if bags1 == 0 or bags2 == 0:
            continue
        
        # Check constraint: at least one store has exactly L bags
        if bags1 == L or bags2 == L:
            p1 = price1 / bags1
            p2 = price2 / bags2
            product = p1 * p2
            if min_product is None or product < min_product:
                min_product = product
    
    return min_product

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_potato(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Example 1
        {
            'N': 3, 'L': 1,
            'a': [3, 2, 1],
            'c': [1, 2, 3],
            'expected': 0.556
        },
        # Example 2
        {
            'N': 3, 'L': 2,
            'a': [2, 2, 2],
            'c': [3, 3, 3],
            'expected': 2.250
        }
    ]
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: N={tc['N']}, L={tc['L']}")
        
        # Calculate expected result using Python reference
        exp = python_solution(tc['N'], tc['L'], tc['a'], tc['c'])
        if exp is None:
            raise TestFailure("Python solution returned None")
        
        # Load inputs
        for j in range(16):
            if j < tc['N']:
                dut.a[j].value = clamp_to_width(tc['a'][j], 8)
                dut.c[j].value = clamp_to_width(tc['c'][j], 16)
            else:
                dut.a[j].value = 0
                dut.c[j].value = 0
        
        dut.N.value = tc['N']
        dut.L.value = tc['L']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=10000)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed)
        
        # Compare with tolerance (3 decimal places)
        if abs(result_float - exp) > 0.001:
            raise TestFailure(f"Expected {exp:.3f}, got {result_float:.3f} (fixed: {result_fixed})")
        
        cocotb.log.info(f"  Result: {result_float:.3f} (expected: {exp:.3f}) - PASS")
        
        # Reset for next test
        await reset_dut(dut, cycles=2)
        await RisingEdge(dut.clk)
        
    cocotb.log.info("All tests passed!")