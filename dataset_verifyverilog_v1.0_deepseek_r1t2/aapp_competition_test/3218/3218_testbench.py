import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4
NUM_PORTS = 8
RESULT_WIDTH = 18
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
        return max(0, value)
    return min(max_val, value)

# ============================================================================
# ARRAY ACCESS HELPERS (for individual ports)
# ============================================================================
async def assign_a_ports(dut, values):
    for i in range(8):
        port_name = f'a{i}'
        if has_signal(dut, port_name):
            if i < len(values):
                val = values[i]
                val_unsigned = from_signed(val, DATA_WIDTH)
                getattr(dut, port_name).value = val_unsigned
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f'Port {port_name} not found')

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
@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_hexagon_coloring(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (1, [[-1]], 1, 'n=1, a=-1'),
        (1, [[6]], 1, 'n=1, a=6'),
        (1, [[0]], 0, 'n=1, a=0'),
        (1, [[3]], 0, 'n=1, a=3'),
        (3, [[-1,2,-1],[2,2],[1,-1,1]], 0, 'n=3, simplified'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, grid, expected, description) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {description}')
        
        flat_values = []
        for row in grid:
            flat_values.extend(row)
        while len(flat_values) < 8:
            flat_values.append(0)
        
        dut.n.value = n
        await assign_a_ports(dut, flat_values)
        
        await start_computation(dut)
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined (X/Z)')
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
    
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')