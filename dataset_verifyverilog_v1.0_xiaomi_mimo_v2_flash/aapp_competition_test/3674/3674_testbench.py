import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
M_WIDTH = 6
N_WIDTH = 6
PQ_WIDTH = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 300000

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
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=15000, timeout_unit="ms")
async def test_find_number_small(dut):
    required_signals = ['clk', 'rst_n', 'start', 'm', 'n', 'p', 'q', 'result', 'done', 'valid']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Required signal '{sig}' not found in DUT")
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (5, 2, 8, 4, 20512),
        (2, 1, 11, 4, None),
        (3, 1, 5, 2, 210),
        (2, 2, 1, 2, None),
        (2, 2, 10, 2, 20),
    ]
    
    filtered_cases = []
    for m, n, p, q, expected in test_cases:
        L = m - n
        if m <= 6 and L <= 4 and p <= 255 and q <= 255 and n >= 1:
            filtered_cases.append((m, n, p, q, expected))
    
    passed = 0
    failed = 0
    
    for i, (m, n, p, q, expected) in enumerate(filtered_cases):
        cocotb.log.info(f"Test {i+1}: m={m}, n={n}, p={p}, q={q}")
        
        try:
            dut.m.value = clamp_to_width(m, M_WIDTH)
            dut.n.value = clamp_to_width(n, N_WIDTH)
            dut.p.value = clamp_to_width(p, PQ_WIDTH)
            dut.q.value = clamp_to_width(q, PQ_WIDTH)
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal is undefined (X/Z)")
            
            valid = int(dut.valid.value)
            
            if expected is None:
                if valid == 1:
                    result = safe_int(dut.result.value)
                    raise TestFailure(f"Expected IMPOSSIBLE but got valid=1, result={result}")
                cocotb.log.info(f"  PASS: Correctly returned IMPOSSIBLE")
                passed += 1
            else:
                if valid != 1:
                    raise TestFailure(f"Expected valid=1 with result={expected}, but got valid=0")
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined (X/Z)")
                
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                cocotb.log.info(f"  PASS: result = {result}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Test Summary: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")