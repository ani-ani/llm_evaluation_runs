import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1
ARRAY_SIZE = 8
RESULT_WIDTH = 4
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

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f'Cannot find array port: {array_name}[{i}] or {port_name}')

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    for i in range(size):
        port_name = f'{array_name}_{i}'
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

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_module(dut):
    """Main test for haybale_sort module."""
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure('DUT must have clk and done signals (sequential module)')

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    # Reset
    await reset_dut(dut)

    # Test cases: (input_string, expected_output, description)
    # Input strings are length 8, using 'C'=0, 'P'=1
    test_cases = [
        ('CCCCCCCC', 0, 'All C'),
        ('PPPPPPPP', 0, 'All P'),
        ('CCCCCCPP', 0, 'Sorted C then P'),
        ('CPPCCCCC', 5, 'Has PPC triple, inv=10'),
        ('PCPPPPPP', 1, 'No 2-inv triple, inv odd'),
        ('PCPCPCPC', 6, 'No 2-inv triple, inv even (alt P)'),
        ('PCCPCCCC', 5, 'Has PCC triple, inv=10'),
    ]

    passed = 0
    failed = 0

    for i, (input_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {desc}')
        # Convert string to list of ints: C->0, P->1
        values = [0 if c == 'C' else 1 for c in input_str]
        # Write inputs
        await write_array(dut, 's', values, DATA_WIDTH)
        # Start computation
        await start_computation(dut)
        # Wait for done
        await wait_for_done(dut)
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined (X/Z)')
        result = int(dut.result.value)
        # Verify
        if result != expected:
            cocotb.log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1

    # Summary
    cocotb.log.info(f'{"="*50}')
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')