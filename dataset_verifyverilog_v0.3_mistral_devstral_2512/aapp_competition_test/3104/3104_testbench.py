import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 4      # Bits per digit (BCD 0-9)
ARRAY_SIZE = 8      # Maximum number of digits
RESULT_WIDTH = 16   # For result signals (not used directly)
CLK_PERIOD_NS = 10
MAX_CYCLES = 2048

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
# TEST HELPER FUNCTIONS
# ============================================================================

def parse_equation(eq_str):
    """Parse equation string 'A=S' into A string and S integer."""
    eq_str = eq_str.strip()
    if '=' not in eq_str:
        raise ValueError(f"Invalid equation format: {eq_str}")
    a_str, s_str = eq_str.split('=', 1)
    return a_str, int(s_str)

def compute_sum_from_split(a_str, split_val, length):
    """Compute sum from A string and split bitmask."""
    total = 0
    start_idx = 0
    for i in range(length):
        # Check if split after digit i
        split_after = False
        if i < length - 1:
            # Extract bit i from split_val
            split_after = (split_val >> i) & 1 == 1
        
        if split_after or i == length - 1:
            num_str = a_str[start_idx:i+1]
            # Handle leading zeros by converting to int
            num_val = int(num_str) if num_str else 0
            total += num_val
            start_idx = i + 1
    
    return total

def construct_equation_string(a_str, split_val, length):
    """Construct equation string from A and split bitmask."""
    result = []
    for i, char in enumerate(a_str):
        result.append(char)
        # Add '+' if split after this digit and not last digit
        if i < length - 1 and ((split_val >> i) & 1):
            result.append('+')
    return ''.join(result)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_equation_solver(dut):
    """Main test function for equation solver."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases: (input_equation, expected_sum, description)
    # A must have <= 8 digits, S <= 200
    test_cases = [
        ("143175=120", 120, "Example 1: 14+31+75=120"),
        ("5025=30", 30, "Example 2: 5+025=30"),
        ("999899=125", 125, "Example 3: 9+9+9+89+9=125"),
        ("123456=100", 100, "Custom: 12+34+56=102 (not 100) - will find alternative"),
        ("888=24", 24, "Simple: 8+8+8=24"),
        ("100=1", 1, "Leading zeros: 1+0+0=1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (eq_str, expected_sum, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Parse equation
            a_str, s_val = parse_equation(eq_str)
            
            # Scale check
            if len(a_str) > ARRAY_SIZE:
                cocotb.log.warning(f"  Skipping: A has {len(a_str)} digits, max allowed {ARRAY_SIZE}")
                continue
            if s_val > 255:
                cocotb.log.warning(f"  Skipping: S={s_val} exceeds 255")
                continue
            
            # Prepare digits array
            digits = [int(c) for c in a_str]
            length = len(digits)
            
            # Pad digits to ARRAY_SIZE
            digits_padded = digits + [0] * (ARRAY_SIZE - length)
            
            # Write inputs
            if is_sequential:
                # Write digits array
                for idx in range(ARRAY_SIZE):
                    dut.digits[idx].value = digits_padded[idx]
                
                # Write length and target
                if has_signal(dut, 'length'):
                    dut.length.value = length
                if has_signal(dut, 'target'):
                    dut.target.value = s_val
                
                # Start computation
                await start_computation(dut)
                await wait_for_done(dut)
                
                # Read split output
                if not is_value_defined(dut.split.value):
                    raise TestFailure("Split output is undefined (X/Z)")
                
                split_val = int(dut.split.value)
                
                # Check valid flag if exists
                if has_signal(dut, 'valid'):
                    if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                        raise TestFailure("Valid flag not asserted")
            else:
                # Combinational module
                for idx in range(ARRAY_SIZE):
                    dut.digits[idx].value = digits_padded[idx]
                
                if has_signal(dut, 'length'):
                    dut.length.value = length
                if has_signal(dut, 'target'):
                    dut.target.value = s_val
                
                # Wait for propagation
                await Timer(100, units='ns')
                
                # Read split output
                if not is_value_defined(dut.split.value):
                    raise TestFailure("Split output is undefined (X/Z)")
                
                split_val = int(dut.split.value)
            
            # Construct equation from output
            eq_output = construct_equation_string(a_str, split_val, length)
            
            # Compute actual sum from split
            actual_sum = compute_sum_from_split(a_str, split_val, length)
            
            # Verify sum matches target
            if actual_sum != s_val:
                raise TestFailure(f"Equation {eq_output} sums to {actual_sum}, expected {s_val}")
            
            # Log result
            cocotb.log.info(f"  PASS: {eq_output} = {actual_sum}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")