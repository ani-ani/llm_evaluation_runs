import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# TEST BENCH
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_canyon_mapper(dut):
    '''Test the CanyonMapper module with the provided examples.'''
    
    # Detect sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    if is_sequential:
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - no reset
        pass
    
    # Test cases: (n, k, vertices, expected_side)
    # vertices: list of (x, y)
    test_cases = [
        (4, 1, [(1,1), (5,1), (5,5), (4,2)], 4.00),
        (6, 3, [(-8,-8), (0,-1), (8,-8), (1,0), (0,10), (-1,0)], 9.00),
        (16, 2, [(0,0), (3,0), (3,3), (6,3), (8,0), (10,4), (10,10), (8,10), (8,6), (6,10), (6,11), (5,9), (4,7), (3,11), (2,1), (0,4)], 9.00)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, vertices, expected) in enumerate(test_cases):
        dut._log.info(f'Test case {i+1}: n={n}, k={k}, expected={expected}')
        
        # Scale coordinates by 100
        scaled_vertices = [(x*100, y*100) for (x, y) in vertices]
        
        # Write n and k
        if has_signal(dut, 'n'):
            dut.n.value = n
        if has_signal(dut, 'k'):
            dut.k.value = k
        
        # Write x and y arrays
        for idx in range(ARRAY_SIZE):
            if idx < len(scaled_vertices):
                x_val, y_val = scaled_vertices[idx]
                # Clamp to width if needed
                x_val = clamp_to_width(x_val, DATA_WIDTH)
                y_val = clamp_to_width(y_val, DATA_WIDTH)
            else:
                x_val = 0
                y_val = 0
            
            # Write to dut.x[idx] and dut.y[idx]
            if has_signal(dut, f'x_{idx}'):
                getattr(dut, f'x_{idx}').value = x_val
            elif has_signal(dut, 'x'):
                dut.x[idx].value = x_val
            
            if has_signal(dut, f'y_{idx}'):
                getattr(dut, f'y_{idx}').value = y_val
            elif has_signal(dut, 'y'):
                dut.y[idx].value = y_val
        
        # Wait a bit for inputs to stabilize
        await Timer(100, units='ns')
        
        # Pulse start
        if is_sequential:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                # Combinational - no start, just wait
                await Timer(100, units='ns')
        else:
            # Combinational - no start, just wait for propagation
            await Timer(100, units='ns')
        
        # Wait for done (if sequential)
        if is_sequential and has_signal(dut, 'done'):
            cycles = 0
            while cycles < MAX_CYCLES:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                cycles += 1
            else:
                raise TestFailure(f'Timeout waiting for done in test {i+1}')
        else:
            # Combinational - wait for propagation
            await Timer(500, units='ns')
        
        # Read side
        if not is_value_defined(dut.side.value):
            raise TestFailure(f'Side output is undefined in test {i+1}')
        
        side_actual = safe_int(dut.side.value)
        side_float = side_actual / 100.0
        
        # Compare
        if abs(side_float - expected) > 0.01:
            dut._log.error(f'Test {i+1} failed: expected {expected}, got {side_float}')
            failed += 1
        else:
            dut._log.info(f'Test {i+1} passed: side = {side_float}')
            passed += 1
    
    # Summary
    dut._log.info('=' * 50)
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')