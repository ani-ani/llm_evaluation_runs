import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

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
# ARMSTRONG CHECKER FUNCTION (Python reference)
# ============================================================================

def armstrong_reference(number):
    """Reference implementation for validation."""
    if number > 255:
        return False  # Out of 8-bit range
    
    sum_val = 0
    times = 0
    temp = number
    
    # Count digits
    while temp > 0:
        times += 1
        temp //= 10
    
    temp = number
    while temp > 0:
        reminder = temp % 10
        sum_val += reminder ** times
        temp //= 10
    
    return number == sum_val

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_armstrong_check(dut):
    """Test Armstrong number checker."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from specification
    test_cases = [
        (153, True, "153 is Armstrong (1^3 + 5^3 + 3^3 = 153)"),
        (259, False, "259 is not Armstrong"),
        (4458, False, "4458 is not Armstrong (4-digit, 4458 > 255, but tests 8-bit)"),
        (0, True, "0 is Armstrong (0^1 = 0)"),
        (1, True, "1 is Armstrong (1^1 = 1)"),
        (153, True, "153 is Armstrong (repeated)"),
        (370, True, "370 is Armstrong (3^3 + 7^3 + 0^3 = 370)"),
        (371, True, "371 is Armstrong (3^3 + 7^3 + 1^3 = 371)"),
        (407, True, "407 is Armstrong (4^3 + 0^3 + 7^3 = 407)"),
        (1634, False, "1634 > 255 (8-bit limit)"),
        (9474, False, "9474 > 255 (8-bit limit)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (number, expected, description) in enumerate(test_cases):
        # Only test numbers within 8-bit range
        if number > 255:
            cocotb.log.info(f"Test {i+1}: SKIPPED - {description}")
            # We still need to run the HDL for 8-bit truncated values to test robustness
            number = number & 0xFF
            expected = armstrong_reference(number)
        
        cocotb.log.info(f"Test {i+1}: {description} (using {number})")
        
        try:
            # Clamp to 8-bit
            input_val = clamp_to_width(number, DATA_WIDTH)
            
            # Write input
            dut.number.value = input_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = bool(int(dut.result.value))
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Random tests
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Running {len(test_cases)} random 8-bit tests...")
    
    random.seed(42)
    for i in range(len(test_cases)):
        number = random.randint(0, 255)
        expected = armstrong_reference(number)
        
        try:
            dut.number.value = number
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = bool(int(dut.result.value))
            
            if result != expected:
                raise TestFailure(f"Random test {i}: {number} expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")