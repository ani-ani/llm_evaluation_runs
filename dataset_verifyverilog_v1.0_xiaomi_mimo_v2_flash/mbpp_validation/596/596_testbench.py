import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'data_valid'):
        dut.data_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def load_data_sequence(dut, data_values, num_elements):
    """Load data values into the DUT."""
    dut.data_valid.value = 1
    for i in range(num_elements):
        dut.data_i.value = clamp_to_width(data_values[i], DATA_WIDTH)
        dut.len_i.value = num_elements
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_size_calculator(dut):
    """Test tuple size calculation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (tuple_elements, description)
    # Note: We simulate the original Python tuples by counting elements
    test_cases = [
        (6, "Test 1: 6 elements (A,1,B,2,C,3)"),
        (6, "Test 2: 6 elements (1, R, 2, N, 3, D)"),
        (4, "Test 3: 4 nested tuples"),
        (1, "Test 4: Single element"),
        (8, "Test 5: Maximum 8 elements"),
        (0, "Test 6: Empty tuple"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_elements, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Create dummy data values (doesn't affect size in this model)
            dummy_data = [1] * num_elements if num_elements > 0 else [0]
            
            # Load data into DUT
            await load_data_sequence(dut, dummy_data, num_elements)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.size_o.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.size_o.value)
            
            # Expected: 40 bytes header + number_of_elements
            expected = 40 + num_elements
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: size = {result} bytes")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
