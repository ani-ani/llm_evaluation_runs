import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4  # Each digit is 4 bits (0-9)
MAX_DIGITS = 8
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

def number_to_digits(n):
    """Convert a number to list of decimal digits."""
    if n == 0:
        return [0]
    digits = []
    while n > 0:
        digits.append(n % 10)
        n //= 10
    return digits[::-1]

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def write_digits(dut, digits):
    """Write digits to individual input ports."""
    # Pad to max length with zeros
    padded = digits + [0] * (MAX_DIGITS - len(digits))
    
    # Write to individual ports: digit_0, digit_1, ...
    for i in range(MAX_DIGITS):
        port = getattr(dut, f'digit_{i}')
        port.value = clamp_to_width(padded[i], DATA_WIDTH)
    
    # Write length
    dut.length.value = clamp_to_width(len(digits), DATA_WIDTH)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_undulating(dut):
    """Test the is_undulating module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (number, expected_result, description)
    test_cases = [
        (1212121, True, "1212121 is undulating"),
        (1991, False, "1991 is not undulating"),
        (121, True, "121 is undulating"),
        (12, False, "12 has len <= 2"),
        (123, False, "123 is not undulating"),
        (1212, True, "1212 is undulating"),
        (111, False, "111 has same digits"),
        (1221, False, "1221 is not undulating"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (number, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Convert number to digits
            digits = number_to_digits(number)
            
            # Write inputs
            await write_digits(dut, digits)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.result.value))
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
