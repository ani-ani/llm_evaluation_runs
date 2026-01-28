import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
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
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
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
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_index_multiplication(dut):
    """Main test function for index-wise multiplication."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (arr1, arr2, expected_result, description)
    test_cases = [
        # Test 1: Original test case
        ([1, 3, 4, 5, 2, 9, 1, 10], [6, 7, 3, 9, 1, 1, 7, 3], 
         [6, 21, 12, 45, 2, 9, 7, 30], "Test 1: Original case"),
        
        # Test 2: Second test case
        ([2, 4, 5, 6, 3, 10, 2, 11], [7, 8, 4, 10, 2, 2, 8, 4], 
         [14, 32, 20, 60, 6, 20, 16, 44], "Test 2: Second case"),
        
        # Test 3: Third test case
        ([3, 5, 6, 7, 4, 11, 3, 12], [8, 9, 5, 11, 3, 3, 9, 5], 
         [24, 45, 30, 77, 12, 33, 27, 60], "Test 3: Third case"),
        
        # Test 4: Zeros
        ([0, 0, 0, 0, 0, 0, 0, 0], [5, 6, 7, 8, 9, 10, 11, 12], 
         [0, 0, 0, 0, 0, 0, 0, 0], "Test 4: Zero array"),
        
        # Test 5: Ones
        ([1, 1, 1, 1, 1, 1, 1, 1], [1, 2, 3, 4, 5, 6, 7, 8], 
         [1, 2, 3, 4, 5, 6, 7, 8], "Test 5: Ones array"),
        
        # Test 6: Max values (255 * 255 = 65025, fits in 16 bits)
        ([255, 255, 255, 255, 255, 255, 255, 255], 
         [255, 255, 255, 255, 255, 255, 255, 255], 
         [65025, 65025, 65025, 65025, 65025, 65025, 65025, 65025], 
         "Test 6: Max values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr1, arr2, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_array(dut, 'arr1', arr1, DATA_WIDTH)
            await write_array(dut, 'arr2', arr2, DATA_WIDTH)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read and verify results
            results = await read_array(dut, 'result', ARRAY_SIZE)
            
            # Check all results are defined
            for idx, res in enumerate(results):
                if res is None:
                    raise TestFailure(f"Result[{idx}] is undefined (X/Z)")
            
            # Compare with expected
            for idx, (actual, expect) in enumerate(zip(results, expected)):
                if actual != expect:
                    raise TestFailure(f"Result[{idx}]: expected {expect}, got {actual}")
            
            cocotb.log.info(f"  PASS: All {ARRAY_SIZE} elements match")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
