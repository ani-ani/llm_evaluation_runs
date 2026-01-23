import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
L_WIDTH = 8
N_MAX = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions (Section A)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Sequential module helpers
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Helper to set distance matrix
def set_dist_matrix(dut, dist_matrix, n):
    for i in range(4):
        for j in range(4):
            port_name = f'dist_{i}{j}'
            if has_signal(dut, port_name):
                if i < n and j < n:
                    val = dist_matrix[i][j]
                else:
                    val = 0
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            else:
                raise TestFailure(f"Port {port_name} not found")

# Brute-force expected result (for reference, not used in test)
def brute_force_expected(n, L, dist_matrix):
    import itertools
    nodes = list(range(n))
    perms = list(itertools.permutations(nodes[1:]))
    for perm in perms:
        total = 0
        prev = 0
        for node in perm:
            total += dist_matrix[prev][node]
            prev = node
        total += dist_matrix[prev][0]
        if total == L:
            return 1
    return 0

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_indoorienteering(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, L, dist_matrix, expected_possible)
    dist1 = [
        [0, 3, 2, 1],
        [3, 0, 1, 3],
        [2, 1, 0, 2],
        [1, 3, 2, 0]
    ]
    dist2 = [
        [0, 1, 2],
        [1, 0, 3],
        [2, 3, 0]
    ]
    dist3 = [
        [0, 5],
        [5, 0]
    ]
    dist4 = [
        [0, 1, 2, 3],
        [1, 0, 4, 5],
        [2, 4, 0, 6],
        [3, 5, 6, 0]
    ]
    
    test_cases = [
        (4, 10, dist1, 1),
        (3, 5, dist2, 0),
        (2, 10, dist3, 1),
        (4, 30, dist4, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, L, dist_matrix, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, L={L}")
        
        # Set inputs
        dut.n.value = n
        dut.L.value = L
        set_dist_matrix(dut, dist_matrix, n)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.possible.value):
            raise TestFailure("Result is undefined (X/Z)")
        
        result = int(dut.possible.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")