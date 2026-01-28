import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
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

def compute_expected(n, p):
    pos = [0] * (n + 1)
    for i, val in enumerate(p):
        pos[val] = i
    max_len = 1
    cur_len = 1
    for v in range(2, n + 1):
        if pos[v] > pos[v - 1]:
            cur_len += 1
        else:
            if cur_len > max_len:
                max_len = cur_len
            cur_len = 1
    if cur_len > max_len:
        max_len = cur_len
    return n - max_len

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sort_moves(dut):
    CLK_NS = 10
    N = 16  # Scaled down from 100k
    
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have 'clk' signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        # Small cases
        [1, 2, 3, 4, 5],
        [5, 4, 3, 2, 1],
        [4, 1, 2, 5, 3],
        [4, 1, 3, 2],
        [2, 1, 4, 3, 6, 5],
        # Random permutations (scaled to 16 max)
        [1, 3, 5, 7, 2, 4, 6, 8, 10, 9, 11, 12, 13, 14, 15, 16],
        [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
        [2, 4, 6, 8, 10, 12, 14, 16, 1, 3, 5, 7, 9, 11, 13, 15],
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14, 16],
        [1, 2, 3, 4, 6, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    ]
    
    passed = 0
    failed = 0
    
    for idx, perm in enumerate(test_cases):
        # Pad or truncate to N elements
        p = perm[:N]
        while len(p) < N:
            p.append(1)  # Pad with 1s (won't affect correctness for these tests)
        
        cocotb.log.info(f"Test {idx + 1}: Permutation {p}")
        
        try:
            # Load permutation into input ports
            for i in range(N):
                port_name = f'p_{i}'
                if has_signal(dut, port_name):
                    # p values are 1-16, need 4 bits
                    getattr(dut, port_name).value = clamp_to_width(p[i], 4)
                else:
                    raise TestFailure(f"Missing input port p_{i}")
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Missing result signal")
            
            result_val = safe_int(dut.result.value)
            expected = compute_expected(N, p)
            
            cocotb.log.info(f"  Result: {result_val}, Expected: {expected}")
            
            if result_val != expected:
                raise TestFailure(f"Mismatch: got {result_val}, expected {expected}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx + 1} FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")
