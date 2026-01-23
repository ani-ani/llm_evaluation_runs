import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE = 8
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_digits(dut, digits):
    """Write digit array to individual ports."""
    for i in range(min(len(digits), 8)):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = digits[i]
        else:
            raise TestFailure(f"Cannot find port: {port_name}")
    # Set length
    if has_signal(dut, 'len'):
        dut.len.value = len(digits)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_to_int(dut):
    """Test tuple to integer conversion."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (digits, expected, description)
    test_cases = [
        ([1, 2, 3], 123, "(1,2,3) -> 123"),
        ([4, 5, 6], 456, "(4,5,6) -> 456"),
        ([5, 6, 7], 567, "(5,6,7) -> 567"),
        ([0], 0, "(0) -> 0"),
        ([9, 9, 9, 9], 9999, "(9,9,9,9) -> 9999"),
        ([1], 1, "(1) -> 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (digits, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write input digits
            await write_digits(dut, digits)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
