import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 9
ARRAY_SIZE = 8
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling individual ports."""
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

async def read_array(dut, array_name, size):
    """Read array values from individual ports."""
    results = []
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    # For combinational module, done should be immediate when start is high
    await Timer(10, units='ns')
    if not is_value_defined(dut.done.value):
        raise TestFailure("Done signal is undefined")
    if int(dut.done.value) != 1:
        raise TestFailure("Done signal not high after start")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_list_subtractor(dut):
    """Test element-wise list subtraction."""
    
    # Detect if sequential (should be combinational based on spec)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Setup clock if present
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - initialize to known state
        dut.start.value = 0
        await Timer(10, units='ns')
    
    # Test cases adapted from problem
    # Format: (list1, list2, expected_results, description)
    test_cases = [
        ([1, 2, 3], [4, 5, 6], [-3, -3, -3], "Basic negative results"),
        ([1, 2], [3, 4], [-2, -2], "Two elements"),
        ([90, 120], [50, 70], [40, 50], "Larger positive results"),
        ([0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], "All zeros"),
        ([255, 128, 64], [0, 0, 0], [255, 128, 64], "Max values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input1: {list1}")
        cocotb.log.info(f"  Input2: {list2}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Pad to array size
            len_val = len(list1)
            padded_list1 = list1 + [0] * (ARRAY_SIZE - len_val)
            padded_list2 = list2 + [0] * (ARRAY_SIZE - len_val)
            
            # Write inputs
            await write_array(dut, 'arr1', padded_list1, DATA_WIDTH)
            await write_array(dut, 'arr2', padded_list2, DATA_WIDTH)
            
            # Set length
            dut.len.value = len_val
            
            # Assert start
            dut.start.value = 1
            
            if is_sequential:
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
                if not is_value_defined(dut.done.value):
                    raise TestFailure("Done signal undefined")
                if int(dut.done.value) != 1:
                    raise TestFailure(f"Done not high, got {int(dut.done.value)}")
            
            # Read results
            result_vals = await read_array(dut, 'result', ARRAY_SIZE)
            
            # Convert to signed and verify only valid elements
            actual_results = []
            for j in range(len_val):
                if result_vals[j] is None:
                    raise TestFailure(f"Result[{j}] is undefined")
                
                # Convert 9-bit unsigned to signed
                signed_val = to_signed(result_vals[j], RESULT_WIDTH)
                actual_results.append(signed_val)
            
            # Verify
            if actual_results != expected:
                raise TestFailure(f"Expected {expected}, got {actual_results}")
            
            cocotb.log.info(f"  Result: {actual_results} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")