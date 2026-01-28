import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 64
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 10000  # Allow more cycles for sequential processing

# Helpers
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
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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

# Array write helpers
def write_array(dut, name, vals, width):
    # Ensure we don't exceed array size
    for i, v in enumerate(vals[:ARRAY_SIZE]):
        if has_signal(dut, name):
            attr = getattr(dut, name)
            if hasattr(attr, '__setitem__'):
                attr[i].value = clamp_to_width(v, width)
            else:
                # Packed array, handle via direct access
                pass
        else:
            # Individual signals arr_0, arr_1, ...
            port = getattr(dut, f'{name}_{i}')
            port.value = clamp_to_width(v, width)

def read_array(dut, name, width, length):
    vals = []
    for i in range(length):
        if has_signal(dut, name):
            attr = getattr(dut, name)
            if hasattr(attr, '__getitem__'):
                v = int(attr[i].value)
            else:
                v = int(attr.value)
        else:
            port = getattr(dut, f'{name}_{i}')
            v = int(port.value)
        # Sign extension if needed (for signed signals)
        vals.append(clamp_to_width(v, width))
    return vals

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference implementation
def python_solve(b_vals):
    # Compute v2 for each number
    v2_counts = {}
    v2_map = {}
    for i, x in enumerate(b_vals):
        cnt = 0
        tmp = x
        while (tmp & 1) == 0 and tmp > 0:
            cnt += 1
            tmp >>= 1
        v2_map[i] = cnt
        v2_counts[cnt] = v2_counts.get(cnt, 0) + 1
    
    # Find max frequency v2
    max_v2 = -1
    max_count = -1
    for k, v in v2_counts.items():
        if v > max_count:
            max_count = v
            max_v2 = k
        elif v == max_count and k < max_v2:  # Arbitrary tie-break
            max_v2 = k
    
    # Output numbers to remove
    removed = []
    for i, x in enumerate(b_vals):
        if v2_map[i] != max_v2:
            removed.append(x)
    return removed

# Testbench
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_bipartite_cut(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input array, expected removed list)
    test_cases = [
        ([1, 2, 3], [2]),  # v2: 0,1,0 -> keep group 0 (count 2), remove 2
        ([2, 6], []),       # v2: 1,1 -> keep group 1 (count 2), remove nothing
        ([71, 36, 100, 39, 27, 41, 58, 74, 4, 85], [58, 74, 36, 100, 4]),
        ([15, 44, 84, 89, 18, 86, 23, 20, 62, 81], [18, 86, 62, 44, 84, 20]),
        ([100, 68, 37, 10, 6, 74, 39, 56, 8, 42], [37, 39, 100, 68, 56, 8]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp_removed) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input {inp}")
        try:
            n = len(inp)
            # Scale down array size to match HDL (max 16)
            if n > ARRAY_SIZE:
                inp = inp[:ARRAY_SIZE]
                n = ARRAY_SIZE
                
            # Write input
            if is_seq:
                dut.start.value = 1
                # Set len
                if has_signal(dut, 'len'):
                    dut.len.value = n
                # Write array
                write_array(dut, 'arr', inp, DATA_WIDTH)
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            else:
                # Combinational
                if has_signal(dut, 'len'):
                    dut.len.value = n
                write_array(dut, 'arr', inp, DATA_WIDTH)
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result_len'):
                raise TestFailure("Missing result_len signal")
            result_len = int(dut.result_len.value)
            result_vals = read_array(dut, 'result', DATA_WIDTH, result_len)
            
            # Python reference
            exp_vals = python_solve(inp)
            # Ensure length matches
            if result_len != len(exp_vals):
                raise TestFailure(f"Length mismatch: expected {len(exp_vals)}, got {result_len}")
            
            # Check values (order may vary, so convert to sets)
            if set(result_vals) != set(exp_vals):
                raise TestFailure(f"Values mismatch: expected {set(exp_vals)}, got {set(result_vals)}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
