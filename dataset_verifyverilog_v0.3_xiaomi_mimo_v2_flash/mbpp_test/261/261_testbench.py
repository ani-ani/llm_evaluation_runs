import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_tuple_to_ports(dut, prefix, values, element_width):
    for i, val in enumerate(values):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def read_result_from_ports(dut, prefix, size):
    results = []
    for i in range(size):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    dut.rst_n.value = 0
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
async def test_elementwise_division(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ((10, 4, 6, 9), (5, 2, 3, 3), (2, 2, 2, 3)),
        ((12, 6, 8, 16), (6, 3, 4, 4), (2, 2, 2, 4)),
        ((20, 14, 36, 18), (5, 7, 6, 9), (4, 2, 6, 2)),
    ]
    
    passed = 0
    failed = 0
    
    for i, (dividend, divisor, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {dividend} // {divisor} == {expected}")
        
        try:
            await write_tuple_to_ports(dut, 'dividend', dividend, DATA_WIDTH)
            await write_tuple_to_ports(dut, 'divisor', divisor, DATA_WIDTH)
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            results = await read_result_from_ports(dut, 'result', 4)
            
            if any(r is None for r in results):
                raise TestFailure("Some result ports are undefined")
            
            result_tuple = tuple(results)
            
            if result_tuple != expected:
                raise TestFailure(f"Expected {expected}, got {result_tuple}")
            
            cocotb.log.info(f"  PASS: result = {result_tuple}")
            passed += 1
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")