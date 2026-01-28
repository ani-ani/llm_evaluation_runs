import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    '''Check if a cocotb value is defined (not X or Z).'''
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    '''Safely convert cocotb value to int, returning default if X/Z.'''
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    '''Convert unsigned integer to signed (two's complement).'''
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    '''Convert signed integer to unsigned for Verilog assignment.'''
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    '''Check if DUT has a signal with given name.'''
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    '''Clamp value to fit within specified bit width (unsigned).'''
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_array(dut, array_name, values, element_width):
    '''Write values to array, handling different interface styles.'''
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f'Cannot find array port: {array_name}[{i}] or {port_name}')

async def read_array(dut, array_name, size):
    '''Read array values, handling different interface styles.'''
    results = []
    
    # Try 2D array first
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
    
    # Try individual ports
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
    '''Reset the DUT (active-low reset).'''
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    '''Wait for done signal with timeout.'''
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    '''Pulse start signal for one cycle.'''
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PACKING FUNCTION
# ============================================================================
def pack_adjacency(adj):
    '''Pack adjacency matrix (8x8) into 64-bit integer.'''
    result = 0
    for i in range(MAX_N):
        for j in range(MAX_N):
            if adj[i][j]:
                result |= 1 << (i*MAX_N + j)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_max_clique_finder(dut):
    '''Main test function for max_clique_finder.'''
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (N, K, adjacency_matrix, expected_max_clique, description)
    test_cases = [
        # Example from problem statement
        (5, 3, [[0,1,1,0,0],[1,0,1,1,0],[1,1,0,0,1],[0,1,0,0,1],[0,0,1,1,0]], 3, 'sample_case_1'),
        # Second example
        (5, 3, [[0,1,1,0,1],[1,0,0,0,0],[1,0,0,0,0],[0,0,0,0,0],[1,0,0,0,0]], 2, 'sample_case_2'),
        # Additional tests
        (4, 4, [[0,1,1,1],[1,0,1,1],[1,1,0,1],[1,1,1,0]], 4, 'complete_K4'),
        (4, 3, [[0,1,1,0],[1,0,1,0],[1,1,0,1],[0,0,1,0]], 3, 'triangle_plus'),
        (3, 2, [[0,1,0],[1,0,1],[0,1,0]], 2, 'path_3'),
        (2, 1, [[0,0],[0,0]], 1, 'no_edges'),
        (6, 2, [[0,1,0,0,0,0],[1,0,0,0,0,0],[0,0,0,1,0,0],[0,0,1,0,0,0],[0,0,0,0,0,1],[0,0,0,0,1,0]], 2, 'two_edges'),
        (7, 3, [[0,1,1,1,0,0,0],[1,0,1,0,0,0,0],[1,1,0,0,0,0,0],[1,0,0,0,1,1,0],[0,0,0,1,0,1,0],[0,0,0,1,1,0,0],[0,0,0,0,0,0,0]], 3, 'K3+extras'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, adj, expected, description) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: {description} (N={N}, K={K}, expected={expected})')
        
        try:
            # Set inputs
            if has_signal(dut, 'N'):
                dut.N.value = N
            if has_signal(dut, 'K'):
                dut.K.value = K
            dut.adj_packed.value = pack_adjacency(adj)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not has_signal(dut, 'max_size'):
                raise TestFailure('Signal max_size not found')
            
            result = safe_int(dut.max_size.value)
            
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            dut._log.info(f'  PASS')
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f'  FAIL: {e}')
            failed += 1
    
    # Summary
    dut._log.info(f'{"="*50}')
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
