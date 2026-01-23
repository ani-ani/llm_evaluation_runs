import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_GEMS = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL HELPERS
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_gem_collector(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have clk signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (5, 1, 10, 10, [8, 5, 4, 4, 7], [8, 1, 6, 7, 9], 3, "Example 1"),
        (5, 1, 100, 100, [27, 79, 40, 62, 52], [75, 77, 93, 41, 45], 3, "Example 2"),
        (3, 2, 20, 20, [5, 10, 15], [5, 10, 15], 3, "Chain"),
        (1, 1, 10, 10, [5], [5], 1, "Single"),
        (3, 1, 10, 10, [1, 9, 5], [9, 9, 8], 1, "No chain"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, r, w, h, x_vals, y_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            dut.n.value = clamp_to_width(n, 4)
            dut.r.value = clamp_to_width(r, 4)
            dut.w.value = clamp_to_width(w, DATA_WIDTH)
            dut.h.value = clamp_to_width(h, DATA_WIDTH)
            
            for j in range(n):
                if has_signal(dut, f'x_{j}'):
                    getattr(dut, f'x_{j}').value = clamp_to_width(x_vals[j], DATA_WIDTH)
                    getattr(dut, f'y_{j}').value = clamp_to_width(y_vals[j], DATA_WIDTH)
                elif has_signal(dut, 'x'):
                    dut.x[j].value = clamp_to_width(x_vals[j], DATA_WIDTH)
                    dut.y[j].value = clamp_to_width(y_vals[j], DATA_WIDTH)
                else:
                    raise TestFailure(f"Cannot find x/y port for index {j}")
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")