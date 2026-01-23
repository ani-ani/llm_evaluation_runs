import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
    '''Clamp value to fit within specified bit width.'''
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_module(dut):
    '''Main test function.'''
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (n, k, arr_values, expected_result)
    test_cases = [
        (5, 3, [10, 5, 4, 8, 3], 2),
        (5, 3, [10, 11, 12, 13, 14], 0),
        (5, 3, [10, 8, 12, 11, 14], 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, k_val, arr_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: n={n_val}, k={k_val}, arr={arr_vals}')
        
        try:
            # Set n and k
            if has_signal(dut, 'n'):
                dut.n.value = n_val
            if has_signal(dut, 'k'):
                dut.k.value = k_val
            
            # Write array values to arr_0..arr_7
            for idx in range(N):
                port_name = f'arr_{idx}'
                if has_signal(dut, port_name):
                    val = arr_vals[idx] if idx < n_val else 0
                    getattr(dut, port_name).value = val
                else:
                    # Fallback to arr array
                    if idx < n_val:
                        dut.arr[idx].value = arr_vals[idx]
                    else:
                        dut.arr[idx].value = 0
            
            # Start computation
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f'Result is undefined (X/Z)')
            
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
