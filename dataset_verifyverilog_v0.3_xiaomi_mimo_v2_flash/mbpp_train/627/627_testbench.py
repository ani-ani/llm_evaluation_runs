import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_CYCLES = 100
CLK_PERIOD_NS = 10

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def write_array(dut, values):
    """Write array values to individual ports."""
    for i, val in enumerate(values):
        if i >= 8:
            break
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Port arr_{i} not found")
    # Set length
    dut.len.value = len(values)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_first_missing(dut):
    """Test the find_first_missing module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array_values, expected_result, description)
    test_cases = [
        ([0, 1, 2, 3], 4, "Test 1: All consecutive from 0"),
        ([0, 1, 2, 6, 9], 3, "Test 2: Missing 3"),
        ([2, 3, 5, 8, 9], 0, "Test 3: Missing 0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (array_vals, expected, description) in enumerate(test_cases):
        dut._log.info(f"Running {description}")
        
        try:
            # Write inputs
            await write_array(dut, array_vals)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: Got {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*40}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
