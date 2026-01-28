import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 16
ARRAY_SIZE = 100
CLK_NS = 10
MAX_CYCLES = 50000  # Large due to log(n) cycles for matrix mult

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

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Fixed point conversion helpers for testbench
Q8_8 = 256
Q24_24 = 2**24

def float_to_q8_8(f):
    return int(f * Q8_8)

def q24_24_to_float(v):
    # Handle signed 48-bit value
    if v >= 2**47:
        v -= 2**48
    return v / Q24_24

async def write_t_matrix(dut, t_vals):
    # t is an array of k elements, each 16 bits
    # Assuming dut.t is a list of signals t[0]...t[k-1]
    k = len(t_vals)
    for i in range(k):
        val = float_to_q8_8(t_vals[i])
        dut.t[i].value = clamp_to_width(val, 16)

async def write_u_matrix(dut, u_vals, k):
    # u is 2D array k*k. Assuming dut.u[i][j]
    for i in range(k):
        for j in range(k):
            val = float_to_q8_8(u_vals[i][j])
            dut.u[i][j].value = clamp_to_width(val, 16)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_ice_cream(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Sample Input
    n = 20
    k = 3
    a = 5
    b = 5
    t = [0.0, 0.0, 0.0]
    u = [
        [0.0, -10.0, 0.0],
        [30.0, 0.0, 0.0],
        [0.0, 0.0, 0.0]
    ]
    
    # Expected: Path 1->2->1->2... (alternating)
    # Cost for 20 scoops = 20*5 + 5 = 105
    # Tastiness: 10 edges of (t[2]+u[1][2]=30) + 10 edges of (t[1]+u[2][1]=0)
    # Wait, input definition:
    # u[i][j] is taste when i is on top of j.
    # If we have sequence j, i... then edge is j->i, weight u[i][j] + t[i].
    # Max path for n=20: Start with flavour 2, then add flavour 1. 
    # Edge 2->1: u[1][2] + t[1] = 30 + 0 = 30.
    # Edge 1->2: u[2][1] + t[2] = 0 + 0 = 0.
    # 20 scoops means 19 transitions. 
    # Best path: 2,1,2,1,2,1... (Start with 2 to get 30s)
    # 19 transitions: 10 edges of weight 30, 9 edges of weight 0. 
    # Total Tastiness = 300.
    # Wait, n=20 scoops. Flavours: F2, F1, F2, F1... (20 items)
    # Transitions: 19 items. 
    # Actually, if we start with F2, we have no cost for the first scoop (just t[2]).
    # But the problem asks for TOTAL tastiness. 
    # Let's assume the matrix logic covers transitions.
    # If we simply maximize per scoop: 30 is max edge weight. 
    # 19 edges * 30 = 570. + initial scoop taste (0) = 570.
    # Wait, re-read: u[i][j] is additional tastiness when i is on top of j.
    # So if stack is ...j, i, tastiness adds u[i][j]. Total tastiness = sum(t_i) + sum(u_{i,j}).
    # Max edge in graph (for transition): u[i][j] + t[i].
    # Max path of length 19 (20 nodes): 19 * 30 = 570. 
    # Wait, is t[i] included? Yes. 
    # So total tastiness = 570 (assuming we pick best transitions).
    # Cost = 20*5 + 5 = 105.
    # Ratio = 570 / 105 ≈ 5.42. 
    # Wait, sample output is 2.
    # Re-evaluate sample: 
    # u[1][2] = 30 (F1 on top of F2). 
    # Sequence: F2, F1. Tastiness: t[2] + t[1] + u[1][2] = 0 + 0 + 30 = 30.
    # Sequence: F2, F1, F2. Tastiness: 0 + 0 + 0 + u[1][2] + u[2][1] = 30 + 0 = 30.
    # Avg per scoop = 30/3 = 10.
    # Wait. If u[1][2] = 30, u[2][1] = 0.
    # 20 scoops. Pattern: F2, F1, F1, F1... 
    # If we stick to F1 on top of F2: F2, F1. T=30. 
    # If we add more F1 on top: F2, F1, F1. T = 30 + u[1][1] (0) + t[1] (0) = 30.
    # So best is alternating if u[2][1] > 0, or stick to single if 0.
    # Here u[2][1] = 0.
    # So best is F2, F1. T=30. Cost=2*5+5=15. Ratio=2.
    # Ah, n=20, but we can choose fewer scoops.
    # 2 scoops give ratio 2. 
    # 3 scoops: (30+0)/20 = 1.5.
    # 20 scoops: 30 / (20*5+5) = 30/105 = 0.28.
    # So optimal is 2 scoops.
    
    expected_ratio = 2.0
    
    # Input writing
    dut.n.value = n
    dut.k.value = k
    dut.a.value = a
    dut.b.value = b
    await write_t_matrix(dut, t)
    await write_u_matrix(dut, u, k)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    await wait_for_done(dut, max_cycles=20000)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
        
    raw_res = int(dut.result.value)
    actual_ratio = q24_24_to_float(raw_res)
    
    # Check tolerance
    diff = abs(actual_ratio - expected_ratio)
    rel_err = diff / expected_ratio if expected_ratio != 0 else diff
    
    if rel_err > 0.00001 and diff > 0.00001:
        raise TestFailure(f"Ratio mismatch: expected {expected_ratio}, got {actual_ratio} (diff {diff})")
        
    cocotb.log.info(f"Test 1 passed. Result: {actual_ratio}")
    
    # Test Case 2: 10 1 8 20
    # n=10, k=1, a=8, b=20
    # t=[5], u=[[0]]
    # Any number of scoops s:
    # Tastiness = s * 5 (since u[0][0]=0)
    # Cost = s*8 + 20
    # Ratio = 5s / (8s+20). Derivative wrt s > 0? d/ds (5s/(8s+20)) = (5(8s+20) - 5s(8)) / denom^2 = 100 / denom^2 > 0.
    # So max at s=10.
    # T = 50. Cost = 80+20=100. Ratio = 0.5.
    
    n = 10
    k = 1
    a = 8
    b = 20
    t = [5.0]
    u = [[0.0]]
    
    expected_ratio_2 = 0.5
    
    await reset_dut(dut)
    
    dut.n.value = n
    dut.k.value = k
    dut.a.value = a
    dut.b.value = b
    await write_t_matrix(dut, t)
    await write_u_matrix(dut, u, k)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut, max_cycles=20000)
    
    raw_res = int(dut.result.value)
    actual_ratio = q24_24_to_float(raw_res)
    
    diff = abs(actual_ratio - expected_ratio_2)
    if diff > 0.00001:
        raise TestFailure(f"Test 2 Ratio mismatch: expected {expected_ratio_2}, got {actual_ratio}")
        
    cocotb.log.info(f"Test 2 passed. Result: {actual_ratio}")