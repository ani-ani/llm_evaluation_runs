import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N = 8
K_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_array(dut, values, element_width):
    for i in range(N):
        if i < len(values):
            val = clamp_to_width(values[i], element_width)
        else:
            val = 0
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = val
        else:
            raise TestFailure(f'Missing signal arr_{i}')

async def read_array(dut):
    results = []
    for i in range(N):
        if has_signal(dut, f'arr_{i}'):
            val = getattr(dut, f'arr_{i}').value
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
async def test_tree_diff(dut):
    """Test the tree_diff module with small inputs."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (arr_values, k, expected_min_diff, description)
    test_cases = [
        # Example 1: 8 trees, k=2, heights 1..8 -> min diff 1
        ([1,2,3,4,5,6,7,8], 2, 1, 'Consecutive 1..8, k=2'),
        # Example 2: 8 trees, k=3, pattern 5,1,5,1,5,1,5,1 -> min diff 4
        ([5,1,5,1,5,1,5,1], 3, 4, 'Alternating 5/1, k=3'),
        # Example 3: 8 trees, k=4, heights 1..8 -> min diff 3
        ([1,2,3,4,5,6,7,8], 4, 3, 'Consecutive 1..8, k=4'),
        # Example 4: 8 trees, k=8, same array -> diff 7
        ([1,2,3,4,5,6,7,8], 8, 7, 'Full array k=8'),
        # Example 5: 8 trees, k=2, heights 10,20,30,40,50,60,70,80 -> min diff 10
        ([10,20,30,40,50,60,70,80], 2, 10, 'Even spaced, k=2'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, k_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {desc}')
        
        try:
            # Write input array
            await write_array(dut, arr_vals, DATA_WIDTH)
            # Set k
            dut.k.value = k_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure('Result is undefined (X/Z)')
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
