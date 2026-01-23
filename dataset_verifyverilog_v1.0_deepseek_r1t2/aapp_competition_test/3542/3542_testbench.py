import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

# ============================================================================
# SEQUENTIAL HELPERS
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    # Detect sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (N, M, A1_x, A1_y, A2_x, A2_y, B1_x, B1_y, B2_x, B2_y, expected_possible, expected_result)
    test_cases = [
        (6, 3, 2, 3, 4, 0, 0, 2, 6, 1, 0, 0),
        (6, 6, 2, 1, 5, 4, 4, 0, 4, 5, 1, 15),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y, exp_possible, exp_result) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, M={M}, A1=({A1x},{A1y}), A2=({A2x},{A2y}), B1=({B1x},{B1y}), B2=({B2x},{B2y})")
        
        try:
            # Set inputs
            dut.N.value = N
            dut.M.value = M
            dut.A1_x.value = A1x
            dut.A1_y.value = A1y
            dut.A2_x.value = A2x
            dut.A2_y.value = A2y
            dut.B1_x.value = B1x
            dut.B1_y.value = B1y
            dut.B2_x.value = B2x
            dut.B2_y.value = B2y
            
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.is_possible.value):
                raise TestFailure("is_possible is undefined (X/Z)")
            if not is_value_defined(dut.result.value):
                raise TestFailure("result is undefined (X/Z)")
            
            actual_possible = int(dut.is_possible.value)
            actual_result = int(dut.result.value)
            
            if actual_possible != exp_possible:
                raise TestFailure(f"is_possible mismatch: expected {exp_possible}, got {actual_possible}")
            if actual_possible == 1 and actual_result != exp_result:
                raise TestFailure(f"result mismatch: expected {exp_result}, got {actual_result}")
            
            cocotb.log.info(f"  PASS: is_possible={actual_possible}, result={actual_result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")