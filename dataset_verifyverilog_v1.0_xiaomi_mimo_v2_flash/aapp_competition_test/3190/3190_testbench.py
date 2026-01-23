import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
N_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# Helper functions
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
        return value & max_val
    return min(max_val, max(0, value))

# Array write helper
def write_array(dut, values, N):
    for i in range(N_MAX):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            val = values[i] if i < N else 0
            val = clamp_to_width(val, DATA_WIDTH)
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f'Port {port_name} not found')

# Reset helper
async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Start helper
async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Wait for done
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# Main test
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_voodoo_counter(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (3, 3, [1,2,3], 1),
        (3, 2, [1,3,2], 5),
        (1, 5, [5], 1),
        (2, 1, [0,2], 2),
        (4, 10, [5,5,5,5], 0),
        (4, 5, [5,5,5,5], 10),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, P, values, expected) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: N={N}, P={P}, values={values}, expected={expected}')
        
        dut.N.value = N
        dut.P.value = P
        write_array(dut, values, N)
        
        await start_computation(dut)
        
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f'Test {i+1} failed: {e}')
            failed += 1
            continue
        
        if not is_value_defined(dut.result.value):
            dut._log.error(f'Test {i+1} failed: result undefined')
            failed += 1
            continue
        
        result = int(dut.result.value)
        if result != expected:
            dut._log.error(f'Test {i+1} failed: expected {expected}, got {result}')
            failed += 1
        else:
            dut._log.info(f'Test {i+1} passed: result={result}')
            passed += 1
    
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')