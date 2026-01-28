import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, array_name, values, element_width):
    for i, val in enumerate(values):
        if has_signal(dut, f'{array_name}_{i}'):
            getattr(dut, f'{array_name}_{i}').value = clamp_to_width(val, element_width)
        else:
            try:
                getattr(dut, array_name)[i].value = clamp_to_width(val, element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find array port: {array_name}[{i}]")

async def read_array(dut, array_name, size):
    results = []
    for i in range(size):
        if has_signal(dut, f'{array_name}_{i}'):
            val = getattr(dut, f'{array_name}_{i}').value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            try:
                val = getattr(dut, array_name)[i].value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
                results.append(None)
    return results

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_toll(dut):
    """Test the min_toll module with scaled examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (entrances, exits, expected_result)
    test_cases = [
        # Example 1: 3 trucks -> scaled to 8 elements by padding with large values
        ([3, 45, 60, 255, 255, 255, 255, 255], 
         [10, 25, 65, 255, 255, 255, 255, 255], 
         32),
        # Example 2: 3 trucks -> scaled to 8 elements
        ([5, 6, 8, 255, 255, 255, 255, 255],
         [5, 7, 8, 255, 255, 255, 255, 255],
         5),
    ]
    
    passed = 0
    failed = 0
    
    for i, (entrances, exits, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: entrances={entrances[:3]}, exits={exits[:3]}")
        
        # Write inputs
        await write_array(dut, 'entrances', entrances, DATA_WIDTH)
        await write_array(dut, 'exits', exits, DATA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")