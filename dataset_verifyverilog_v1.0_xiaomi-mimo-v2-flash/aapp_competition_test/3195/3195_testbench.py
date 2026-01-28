import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 32
CLK_NS = 10
TIMEOUT_CYCLES = 10000  # Allow plenty of cycles for sequential processing

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

def clamp_to_width(v, bits):
    # Handle negative values for signed simulation if needed, though inputs are positive
    if v < 0:
        v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_fixed(val, shift=16):
    return int(val * (1 << shift))

def from_fixed(val, shift=16):
    return val / (1 << shift)

# Python Reference Implementation for Test Cases
def solve_python(Tg, Ty, Tr, obs, query):
    C = Tg + Ty + Tr
    colors = {'green': 0, 'yellow': 1, 'red': 2}
    
    # Allowed intervals for T (mod C)
    intervals = [(0, C)]
    
    for t, c_str in obs:
        c = colors[c_str]
        # T must satisfy the observation
        if c == 0: # Green
            low = t - Tg
            high = t
        elif c == 1: # Yellow
            low = t - Tg - Ty
            high = t - Tg
        else: # Red
            low = t - C
            high = t - Tg - Ty
        
        # Normalize to [0, C)
        low = low % C
        high = high % C
        
        new_intervals = []
        if low < high:
            new_intervals.append((low, high))
        else:
            new_intervals.append((low, C))
            new_intervals.append((0, high))
        
        # Intersect
        next_intervals = []
        for start, end in intervals:
            for n_start, n_end in new_intervals:
                inter_s = max(start, n_start)
                inter_e = min(end, n_end)
                if inter_s < inter_e:
                    next_intervals.append((inter_s, inter_e))
        
        # Merge
        next_intervals.sort()
        merged = []
        for s, e in next_intervals:
            if merged and merged[-1][1] >= s:
                merged[-1] = (merged[-1][0], max(merged[-1][1], e))
            else:
                merged.append((s, e))
        intervals = merged
        if not intervals:
            return 0.0
    
    total_len = sum(e - s for s, e in intervals)
    if total_len == 0:
        return 0.0
        
    # Query interval
    qt, qc_str = query
    qc = colors[qc_str]
    if qc == 0: # Green
        q_low = qt - Tg
        q_high = qt
    elif qc == 1: # Yellow
        q_low = qt - Tg - Ty
        q_high = qt - Tg
    else: # Red
        q_low = qt - C
        q_high = qt - Tg - Ty
    
    q_low = q_low % C
    q_high = q_high % C
    
    q_ints = []
    if q_low < q_high:
        q_ints.append((q_low, q_high))
    else:
        q_ints.append((q_low, C))
        q_ints.append((0, q_high))
        
    favorable_len = 0
    for start, end in intervals:
        for qs, qe in q_ints:
            s = max(start, qs)
            e = min(end, qe)
            if s < e:
                favorable_len += (e - s)
                
    return favorable_len / total_len

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_traffic_light(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start_query'): dut.start_query.value = 0
        if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        dut.rst_n.value = 1

    test_cases = [
        {
            "input": "4 4 4\n3\n2 green\n18 yellow\n34 red\n5 green",
            "exp": 0.25
        },
        {
            "input": "4 4 4\n4\n2 green\n6 yellow\n10 red\n14 green\n4 red",
            "exp": 0.0
        },
        {
            "input": "6 6 6\n6\n5 green\n6 green\n9 yellow\n12 yellow\n15 red\n19 red\n7 green",
            "exp": 1.0
        }
    ]

    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}")
        lines = tc["input"].strip().split('\n')
        
        # Parse Header
        parts = lines[0].split()
        Tg = int(parts[0]); Ty = int(parts[1]); Tr = int(parts[2])
        
        # Parse Obs
        n = int(lines[1])
        obs = []
        for i in range(n):
            l = lines[2+i].split()
            obs.append((int(l[0]), l[1]))
            
        # Parse Query
        q_line = lines[2+n].split()
        query = (int(q_line[0]), q_line[1])
        
        # Calculate Expected
        py_prob = solve_python(Tg, Ty, Tr, obs, query)
        # Expected result in Q16.16
        exp_res = int(py_prob * (1 << 16))
        
        # HDL Input Setup
        dut_val_Tg = to_fixed(Tg)
        dut_val_Ty = to_fixed(Ty)
        dut_val_Tr = to_fixed(Tr)
        
        # Load Cycle Params
        if has_signal(dut, 'Tg'):
            dut.Tg.value = dut_val_Tg
            dut.Ty.value = dut_val_Ty
            dut.Tr.value = dut_val_Tr
            await RisingEdge(dut.clk)
        
        # Stream Observations
        if has_signal(dut, 'valid_in'):
            for t, c_str in obs:
                dut.obs_t.value = to_fixed(t)
                dut.obs_c.value = 0 if c_str == 'green' else 1 if c_str == 'yellow' else 2
                dut.valid_in.value = 1
                await RisingEdge(dut.clk)
                dut.valid_in.value = 0
                await RisingEdge(dut.clk)  # Allow processing cycle
        
        # Send Query
        if has_signal(dut, 'start_query'):
            dut.obs_t.value = to_fixed(query[0])
            dut.obs_c.value = 0 if query[1] == 'green' else 1 if query[1] == 'yellow' else 2
            dut.start_query.value = 1
            await RisingEdge(dut.clk)
            dut.start_query.value = 0
        
        # Wait for done
        done = False
        for _ in range(TIMEOUT_CYCLES):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout for case {idx+1}")
        
        # Check Result
        if has_signal(dut, 'result'):
            res = int(dut.result.value)
            # Check with tolerance for fixed-point calculation errors
            if abs(res - exp_res) > 50: # ~0.0007 error tolerance
                 got_float = res / 65536.0
                 raise TestFailure(f"Case {idx+1}: Expected {exp_res} ({py_prob:.4f}), got {res} ({got_float:.4f})")
        else:
             raise TestFailure("No result signal found")
