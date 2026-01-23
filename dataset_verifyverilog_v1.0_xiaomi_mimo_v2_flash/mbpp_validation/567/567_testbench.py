import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 1
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            # Try indexed array
            try:
                getattr(dut, array_name)[i].value = clamp_to_width(val, element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
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
            # Try indexed array
            try:
                val = getattr(dut, array_name)[i].value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
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
async def test_is_sorted_check(dut):
    """Main test function for is_sorted_check module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (inputs, expected_output, description)
    # Each input is a tuple of (array_values, length, expected_result)
    test_cases = [
        # Test 1: Sorted ascending
        ([1,2,4,6,8,10,12,14,16,17], 10, 1, "Sorted ascending"),
        # Test 2: Not sorted (20 before 17)
        ([1,2,4,6,8,10,12,14,20,17], 10, 0, "Not sorted: 20 > 17"),
        # Test 3: Not sorted (15 before 14)
        ([1,2,4,6,8,10,15,14,20], 9, 0, "Not sorted: 15 > 14"),
        # Additional edge cases
        ([5], 1, 1, "Single element"),
        ([3, 3, 3, 3], 4, 1, "All equal values"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, 1, "Full sorted array"),
        ([8, 7, 6, 5, 4, 3, 2, 1], 8, 0, "Reverse sorted"),
        ([1, 5, 3, 7, 9, 2, 4, 8], 8, 0, "Random unsorted"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (values, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        
        try:
            # Validate test case length
            if length > ARRAY_SIZE:
                raise TestFailure(f"Length {length} exceeds ARRAY_SIZE {ARRAY_SIZE}")
            
            # Truncate values if needed and pad with zeros
            test_values = values[:ARRAY_SIZE]
            while len(test_values) < ARRAY_SIZE:
                test_values.append(0)
            
            # Write inputs to individual ports
            for i in range(ARRAY_SIZE):
                port_name = f"arr_{i}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(test_values[i], DATA_WIDTH)
                else:
                    raise TestFailure(f"Signal arr_{i} not found")
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = length
            else:
                raise TestFailure("Signal 'len' not found")
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure(f"Result is undefined (X/Z)")
                
                result = int(dut.result.value)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure(f"Result is undefined (X/Z)")
                
                result = int(dut.result.value)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result} (expected {expected})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")