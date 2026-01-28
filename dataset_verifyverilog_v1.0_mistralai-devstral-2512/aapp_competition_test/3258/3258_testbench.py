import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 200000
Q8_8 = 256.0  # 2^8
Q16_16 = 65536.0  # 2^16

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Python reference implementation
def compute_min_velocity(n, mice, m):
    """Compute minimum initial velocity for cat to eat all mice"""
    from math import sqrt
    
    # Precompute distances
    dist = [[0.0] * n for _ in range(n)]
    dist_origin = [0.0] * n
    
    for i in range(n):
        x1, y1, s1 = mice[i]
        dist_origin[i] = sqrt(x1*x1 + y1*y1)
        for j in range(n):
            x2, y2, s2 = mice[j]
            dist[i][j] = sqrt((x1-x2)**2 + (y1-y2)**2)
    
    # DP: dp[mask][i] = minimum initial velocity to eat mice in mask ending at i
    INF = float('inf')
    dp = [[INF] * n for _ in range(1 << n)]
    
    # Base case: start from origin to each mouse
    for i in range(n):
        x, y, s = mice[i]
        dist0 = sqrt(x*x + y*y)
        # v * 1 >= dist0 / s  => v >= dist0 / s
        dp[1 << i][i] = dist0 / s
    
    # DP transitions
    for mask in range(1, 1 << n):
        for i in range(n):
            if not (mask & (1 << i)):
                continue
            if dp[mask][i] == INF:
                continue
            
            # Try going to each uneaten mouse j
            for j in range(n):
                if mask & (1 << j):
                    continue
                
                # Distance to travel
                d = dist[i][j]
                # Time available: s_j - (time already spent)
                # Time spent so far: sum of distances / velocity
                # But velocity is decreasing, so compute needed velocity
                
                # Current number of mice eaten
                k = bin(mask).count('1')
                
                # Velocity before eating mouse i: v_current = v_initial * (m)^k
                # Time to go from i to j: d / (v_current * m) = d / (v_initial * m^(k+1))
                # Total time at mouse j: time_so_far + d / (v_initial * m^(k+1)) <= s_j
                
                # We need to solve for v_initial
                # time_so_far = sum of distances / velocity at each step
                # This is complex, so we use the DP that tracks required initial velocity
                
                # Instead, we can compute minimum v_initial needed to reach j from current state
                # Let v = dp[mask][i] (minimum v_initial to reach state (mask, i))
                # At mouse i, velocity = v * m^k
                # Time to reach j = d / (v * m^(k+1))
                # We need: time_so_far + d / (v * m^(k+1)) <= s_j
                
                # But time_so_far is not directly stored. Instead, we compute v_new
                # such that we can reach j within deadline.
                
                # Actually, the DP state should store the minimum v_initial
                # that allows reaching (mask, i) within all deadlines.
                # For transition to j, we need:
                # v_new = max(dp[mask][i], d / (s_j - t_i) / m^(k+1))
                # where t_i is the time at mouse i.
                
                # Since we don't track time, we use a different formulation:
                # dp[mask | (1<<j)][j] = min over i of max(dp[mask][i], 
                #     dist_origin[j]/s_j if mask is empty else 
                #     dist[i][j]/(s_j - time_i) / m^(k+1))
                
                # This is complex. Let's use the standard TSP DP with time constraints:
                # dp[mask][i] = minimum v_initial to finish mask ending at i
                # Transition: for j not in mask:
                #   t_next = time to reach j from i at velocity v_current * m
                #   v_required = dist[i][j] / (s_j - t_i)
                #   new_v = max(dp[mask][i], v_required * m^(-k-1))
                
                # For simplicity in Verilog, we'll compute velocity required at each step
                # and track the maximum needed initial velocity.
                
                # Let's compute time_so_far in terms of v_initial:
                # time_so_far = sum over path of dist / (v_initial * m^step)
                # This is geometric series: time = (1/v_initial) * sum(dist / m^step)
                # So v_initial >= sum(dist / m^step) / s_j
                
                # We'll precompute for each path the required v_initial.
                # Since n is small, we can iterate over all permutations in Python.
                pass
    
    # Brute force over all permutations for n <= 15 (2^15 * 15 = 49152)
    # For each permutation, compute required v_initial
    # This is what the Verilog will do via DP.
    
    # For n=15, 15! is too large, but 2^15 * 15 is manageable.
    # We use DP over subsets.
    
    # Redefine DP:
    # dp[mask][i] = tuple (v_initial, time_at_i) but time depends on v_initial.
    # Instead, we compute the required v_initial to reach (mask, i) within deadlines.
    # For each state, we store the minimum v_initial.
    # Transition: to reach j from i, we need v_initial such that:
    #   time_i + dist[i][j] / (v_initial * m^(k+1)) <= s_j
    #   where time_i = sum_{steps} dist / (v_initial * m^step)
    #   => v_initial >= sum_{steps} dist / m^step / (s_j - time_i) ???
    
    # This is getting too complex for direct calculation.
    # Let's use binary search on v_initial in the testbench.
    # In Verilog, we'll implement DP that computes for a given v_initial whether all mice can be eaten.
    # Then we'll binary search over v_initial.
    
    return 0.0  # Placeholder

# Binary search in Python for reference
def check_velocity(mice, m, v_initial):
    """Check if given initial velocity can eat all mice"""
    from math import sqrt
    n = len(mice)
    
    # Try all permutations via DP
    # dp[mask][i] = minimum time to eat mice in mask ending at i
    INF = float('inf')
    dp = [[INF] * n for _ in range(1 << n)]
    
    for i in range(n):
        x, y, s = mice[i]
        dist = sqrt(x*x + y*y)
        if dist <= v_initial * s + 1e-9:
            dp[1 << i][i] = dist / v_initial
    
    for mask in range(1, 1 << n):
        for i in range(n):
            if not (mask & (1 << i)) or dp[mask][i] == INF:
                continue
            k = bin(mask).count('1')
            vel = v_initial * (m ** k)
            for j in range(n):
                if mask & (1 << j):
                    continue
                xj, yj, sj = mice[j]
                xi, yi, _ = mice[i]
                dist = sqrt((xj - xi)**2 + (yj - yi)**2)
                time_next = dp[mask][i] + dist / vel
                if time_next <= sj + 1e-9:
                    dp[mask | (1 << j)][j] = min(dp[mask | (1 << j)][j], time_next)
    
    return any(dp[(1 << n) - 1][i] < INF for i in range(n))

def binary_search_velocity(mice, m, lo=0.01, hi=100000.0, tol=1e-4):
    """Binary search for minimum velocity"""
    for _ in range(50):  # Enough iterations for 1e-4 precision
        mid = (lo + hi) / 2
        if check_velocity(mice, m, mid):
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2

# Test cases
TEST_CASES = [
    {
        'n': 1,
        'mice': [(3, 4, 2)],
        'm': 0.75,
        'expected': 2.5
    },
    {
        'n': 2,
        'mice': [(0, 100, 10), (0, -100, 100)],
        'm': 0.80,
        'expected': 10.0
    },
    {
        'n': 2,
        'mice': [(0, 100, 10), (0, -100, 15)],
        'm': 0.80,
        'expected': 23.33333333
    }
]

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_mice(dut, n, mice):
    """Write mouse data to DUT"""
    for i in range(n):
        x, y, s = mice[i]
        # Convert to fixed-point
        x_fp = from_signed(x, 12)
        y_fp = from_signed(y, 12)
        s_fp = int(s * 4096)  # Q2.12 (2^12 = 4096)
        
        # Write to ports
        dut.mouse_x[i].value = x_fp
        dut.mouse_y[i].value = y_fp
        dut.mouse_s[i].value = s_fp

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cartesian_cat(dut):
    """Test Cartesian Cat module with multiple test cases"""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Check required signals
    required_signals = ['start', 'm', 'num_mice', 'result', 'done', 'valid']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(TEST_CASES):
        cocotb.log.info(f"Test case {i+1}: n={tc['n']}, m={tc['m']}")
        
        try:
            # Write inputs
            dut.num_mice.value = tc['n']
            dut.m.value = int(tc['m'] * 256)  # Q8.8
            
            await write_mice(dut, tc['n'], tc['mice'])
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_dut(dut, max_cycles=200000)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_fp = int(dut.result.value)
            result = fixed_to_float(result_fp, 16)  # Q16.16
            
            # Check validity
            if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                raise TestFailure("Result not valid")
            
            # Compare with expected
            expected = tc['expected']
            rel_error = abs(result - expected) / max(1e-9, expected)
            abs_error = abs(result - expected)
            
            if rel_error > 1e-3 and abs_error > 1e-3:
                raise TestFailure(f"Result {result} vs expected {expected} (rel={rel_error:.6f}, abs={abs_error:.6f})")
            
            cocotb.log.info(f"PASS: Result={result:.6f}, Expected={expected:.6f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
