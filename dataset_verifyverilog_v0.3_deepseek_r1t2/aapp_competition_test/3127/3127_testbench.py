import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
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

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
MAX_N = 8
MAX_M = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS FOR SEQUENTIAL MODULE
# ============================================================================
async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_network(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, edges, expected_unused_nodes)
    test_cases = [
        (7, 8, [(1,2,2),(1,3,1),(1,4,3),(2,6,1),(2,7,2),(3,5,1),(4,7,2),(5,7,1)], [4,6]),
        (5, 6, [(1,2,2),(2,3,2),(3,5,2),(1,4,3),(4,5,3),(1,5,6)], []),
        (5, 6, [(1,2,2),(2,3,1),(3,5,2),(1,4,3),(4,5,3),(1,5,6)], [4]),
    ]
    
    for idx, (n, m, edges, expected_unused) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: n={n}, m={m}")
        
        # Set n and m
        dut.n.value = n
        dut.m.value = m
        
        # Initialize all edge inputs to 0
        for i in range(MAX_M):
            dut.a_i[i].value = 0
            dut.b_i[i].value = 0
            dut.len_i[i].value = 0
        
        # Set actual edges
        for i, (a, b, l) in enumerate(edges):
            dut.a_i[i].value = a
            dut.b_i[i].value = b
            dut.len_i[i].value = l
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read unused_mask
        mask = int(dut.unused_mask.value)
        
        # Compute expected mask
        exp_mask = 0
        for u in expected_unused:
            exp_mask |= (1 << (u-1))
        
        if mask != exp_mask:
            raise TestFailure(f"Test {idx+1}: expected mask {exp_mask:04b}, got {mask:04b}")
        else:
            cocotb.log.info(f"  PASS: mask = {mask:04b}")
    
    cocotb.log.info("All tests passed!")