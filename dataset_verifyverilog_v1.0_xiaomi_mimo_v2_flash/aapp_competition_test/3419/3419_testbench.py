import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
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
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def set_t_values(dut, t_values):
    # Pad to 8 elements with zeros
    t_padded = t_values + [0] * (8 - len(t_values))
    for i in range(8):
        val = clamp_to_width(t_padded[i], DATA_WIDTH)
        setattr(dut, f't{i}', val)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_license_renewal(dut):
    '''Main test for license renewal module.'''
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, s1, s2, t_list, expected_max)
    test_cases = [
        (5, 20, 20, [7, 11, 9, 12, 2], 4),
        (5, 100, 100, [101, 1, 1, 1, 1], 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, s1, s2, t_list, expected) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: n={n}, s1={s1}, s2={s2}, t={t_list}')
        
        # Set inputs
        dut.n.value = n
        dut.s1.value = s1
        dut.s2.value = s2
        await set_t_values(dut, t_list)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.max_count.value):
            raise TestFailure(f'Result is undefined (X/Z)')
        
        result = int(dut.max_count.value)
        
        if result != expected:
            dut._log.error(f'Test {i+1} FAILED: expected {expected}, got {result}')
            failed += 1
        else:
            dut._log.info(f'Test {i+1} PASSED: result = {result}')
            passed += 1
    
    # Summary
    dut._log.info(f'{'='*50}')
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')