import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
T = 4
N = 8
CLK_PERIOD_NS = 10
INF = 0xFFFFFFFF

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

async def wait_for_result(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f'Timeout: result_valid not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_transport_solver(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'num_points': 4,
            'd_min': [100, 200, 300, 400],
            'a': [30000, 20000, 10000, 0],
            'd': [50, 75, 400],
            'h': [10000, 20000, -40000],
            'expected': 2
        },
        {
            'num_points': 3,
            'd_min': [20],
            'a': [50000],
            'd': [100, 10],
            'h': [10000, -60000],
            'expected': INF
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        dut._log.info(f'Testing: num_points={tc["num_points"]}')
        
        # Assign num_points
        dut.num_points.value = tc['num_points']
        
        # Write transportation arrays
        await write_array(dut, 'd_min', tc['d_min'], DATA_WIDTH)
        await write_array(dut, 'a', tc['a'], DATA_WIDTH)
        
        # Write segment arrays (pad with zeros if needed)
        d_padded = tc['d'] + [0] * (N-1 - len(tc['d']))
        h_padded = tc['h'] + [0] * (N-1 - len(tc['h']))
        await write_array(dut, 'd', d_padded, DATA_WIDTH)
        await write_array(dut, 'h', h_padded, DATA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for result
        await wait_for_result(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined')
        
        result = int(dut.result.value)
        
        # Check
        if result == tc['expected']:
            dut._log.info(f'  PASS: result = {result}')
            passed += 1
        else:
            dut._log.error(f'  FAIL: expected {tc["expected"]}, got {result}')
            failed += 1
    
    # Summary
    dut._log.info(f'{'='*50}')
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')