import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 16
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
MAX_PROCLAMATIONS = 100000

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
# ARRAY ACCESS FUNCTIONS
# ============================================================================

async def write_array(dut, array_name, values, size, element_width):
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if i < len(values):
                arr[i].value = clamp_to_width(values[i], element_width)
            else:
                arr[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

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
        port_name = f"{array_name}_{i}"
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
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def read_proclamations(dut, timeout_cycles=1000):
    proclamations = []
    cycles = 0
    while cycles < timeout_cycles:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.proclamation_valid.value) and int(dut.proclamation_valid.value) == 1:
            if is_value_defined(dut.proclamation.value):
                proclamations.append(int(dut.proclamation.value))
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
        cycles += 1
    if cycles >= timeout_cycles:
        raise TestFailure(f"Timeout reading proclamations after {timeout_cycles} cycles")
    return proclamations

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=30, timeout_unit="seconds")
async def test_frog_regent(dut):
    """Test the Frog Regent module with sample cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases
    test_cases = [
        {
            "name": "Sample 1",
            "N": 6,
            "start": [1, 5, 4, 3, 2, 6],
            "target": [1, 2, 5, 4, 3, 6],
        },
        {
            "name": "Sample 2",
            "N": 5,
            "start": [1, 5, 3, 2, 4],
            "target": [1, 5, 4, 2, 3],
        },
    ]
    
    for test_case in test_cases:
        dut._log.info(f"\nRunning test: {test_case['name']}")
        
        # Write inputs
        dut.N.value = test_case['N']
        await write_array(dut, 'start_seq', test_case['start'], 16, DATA_WIDTH)
        await write_array(dut, 'target_seq', test_case['target'], 16, DATA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Read proclamations
        proclamations = await read_proclamations(dut)
        
        # Verify at least some proclamations were generated
        if len(proclamations) == 0:
            raise TestFailure(f"{test_case['name']}: No proclamations generated")
        
        dut._log.info(f"  Generated {len(proclamations)} proclamations: {proclamations}")
        
        # Verify done is high
        if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
            raise TestFailure(f"{test_case['name']}: Done signal not asserted")
        
        # Verify no error
        if has_signal(dut, 'error') and is_value_defined(dut.error.value):
            if int(dut.error.value) == 1:
                raise TestFailure(f"{test_case['name']}: Error signal asserted")
    
    dut._log.info("\n" + "="*50)
    dut._log.info("All tests completed successfully!")
    dut._log.info("="*50)

@cocotb.test(timeout_time=30, timeout_unit="seconds")
async def test_frog_regent_stress(dut):
    """Stress test with larger N and complex sequences."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Stress test: N=16, reverse order
    N = 16
    start = list(range(1, N+1))  # 1,2,3,...,16
    target = [1] + list(range(16, 1, -1))  # 1,16,15,...,2
    
    dut._log.info(f"Stress test: N={N}, reverse order")
    
    # Write inputs
    dut.N.value = N
    await write_array(dut, 'start_seq', start, 16, DATA_WIDTH)
    await write_array(dut, 'target_seq', target, 16, DATA_WIDTH)
    
    # Start computation
    await start_computation(dut)
    
    # Read proclamations
    proclamations = await read_proclamations(dut, timeout_cycles=10000)
    
    # Verify proclamations count within limit
    if len(proclamations) > MAX_PROCLAMATIONS:
        raise TestFailure(f"Generated {len(proclamations)} proclamations, exceeds {MAX_PROCLAMATIONS} limit")
    
    dut._log.info(f"Generated {len(proclamations)} proclamations")
    
    # Verify done is high
    if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
        raise TestFailure("Done signal not asserted in stress test")
    
    # Verify no error
    if has_signal(dut, 'error') and is_value_defined(dut.error.value):
        if int(dut.error.value) == 1:
            raise TestFailure("Error signal asserted in stress test")
    
    dut._log.info("Stress test passed!")