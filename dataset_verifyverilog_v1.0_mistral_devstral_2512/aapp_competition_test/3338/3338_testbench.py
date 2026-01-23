import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N_MAX = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

# ============================================================================
# TEST CASES
# ============================================================================

test_case_1 = {
    "n": 4,
    "k": 1,
    "partners": [
        [78, 61, 88, 71],
        [80, 80, 90, 90],
        [70, 90, 80, 100],
        [90, 70, 0, 0],
    ],
    "expected": 4,
}

test_case_2 = {
    "n": 3,
    "k": 2,
    "partners": [
        [10, 20, 12, 22],
        [15, 15, 0, 0],
        [20, 10, 22, 12],
    ],
    "expected": 3,
}

test_cases = [test_case_1, test_case_2]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_arcaea_diversity(dut):
    """Test the arcaea_diversity module."""
    
    if not has_signal(dut, 'clk') or not has_signal(dut, 'rst_n') or not has_signal(dut, 'start'):
        raise TestFailure("Missing required signals: clk, rst_n, start")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for idx, tc in enumerate(test_cases):
        dut._log.info(f"Running test case {idx+1}: n={tc['n']}, k={tc['k']}")
        
        # Set n and k
        dut.n.value = tc['n']
        dut.k.value = tc['k']
        
        # Set partner data
        partners = tc['partners']
        for i, partner in enumerate(partners):
            if i >= N_MAX:
                break
            g, p, ga, pa = partner
            g = clamp_to_width(g, DATA_WIDTH)
            p = clamp_to_width(p, DATA_WIDTH)
            ga = clamp_to_width(ga, DATA_WIDTH)
            pa = clamp_to_width(pa, DATA_WIDTH)
            getattr(dut, f'g_{i}').value = g
            getattr(dut, f'p_{i}').value = p
            getattr(dut, f'ga_{i}').value = ga
            getattr(dut, f'pa_{i}').value = pa
        
        # Clear unused partners
        for i in range(len(partners), N_MAX):
            getattr(dut, f'g_{i}').value = 0
            getattr(dut, f'p_{i}').value = 0
            getattr(dut, f'ga_{i}').value = 0
            getattr(dut, f'pa_{i}').value = 0
        
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_seen = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test case {idx+1}: Timeout waiting for done")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test case {idx+1}: Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test case {idx+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All test cases passed!")