import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

async def wait_for_done(dut, max_cycles=1000):
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
async def test_rearrange_module(dut):
    """Test the rearrange_to_divisible_by_7 module."""
    
    # Configuration
    DATA_WIDTH = 4  # Each digit is 4 bits
    ARRAY_SIZE = 16
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_string, expected_output_string, description)
    test_cases = [
        ("1689", "1869", "Basic case"),
        ("18906", "18690", "With zero"),
        ("16891", "16198", "Duplicate digit"),
        ("16892", "21896", "Duplicate digit"),
        ("16893", "31689", "Duplicate digit"),
        ("16894", "41986", "Duplicate digit"),
        ("16895", "51968", "Duplicate digit"),
        ("16896", "61698", "Duplicate digit"),
        ("16897", "71869", "Duplicate digit"),
        ("16898", "86198", "Duplicate digit"),
        ("16899", "91896", "Duplicate digit"),
        ("4048169", "4041968", "Multiple digits"),
        ("10994168", "94116890", "Multiple zeros"),
        ("168903", "316890", "Zeros in middle"),
        ("11689", "16198", "Duplicate 1"),
        ("91111168", "11111968", "Many 1's"),
        ("6198", "1869", "Just the four digits"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_str}")
        cocotb.log.info(f"  Expected: {expected_str}")
        
        try:
            # Convert string to list of integers
            input_digits = [int(c) for c in input_str]
            expected_digits = [int(c) for c in expected_str]
            input_length = len(input_digits)
            
            # Pad input to 16 elements with zeros
            while len(input_digits) < ARRAY_SIZE:
                input_digits.append(0)
            
            # Write inputs
            await write_array(dut, 'input_digits', input_digits, DATA_WIDTH)
            dut.input_length.value = input_length
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output
            output_digits = await read_array(dut, 'output_digits', ARRAY_SIZE)
            
            # Extract the first input_length digits from output
            actual_output = []
            for j in range(input_length):
                if j < len(output_digits) and output_digits[j] is not None:
                    actual_output.append(output_digits[j])
                else:
                    raise TestFailure(f"Output digit {j} is undefined")
            
            # Compare with expected
            if actual_output != expected_digits:
                raise TestFailure(f"Output mismatch: got {actual_output}, expected {expected_digits}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
