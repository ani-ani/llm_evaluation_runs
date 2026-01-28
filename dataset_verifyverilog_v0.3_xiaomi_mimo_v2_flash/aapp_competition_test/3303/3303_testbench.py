import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 12   # 3-digit BCD per number
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

# Convert decimal to 3-digit BCD (12 bits)
def dec_to_bcd(num):
    """Convert integer 0-999 to 12-bit BCD (3 digits)."""
    if num < 0 or num > 999:
        raise ValueError("Number out of range for 3-digit BCD")
    units = num % 10
    tens = (num // 10) % 10
    hundreds = (num // 100) % 10
    return (hundreds << 8) | (tens << 4) | units

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_carry_free_steps(dut):
    """Main test for carry_free_steps module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a, b, expected_result)
    test_cases = [
        (10, 99, 1),
        (90, 10, 10),
        (25, 75, 25),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_dec, b_dec, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_dec}, b={b_dec}, expected={expected}")
        
        # Convert to BCD
        a_bcd = dec_to_bcd(a_dec)
        b_bcd = dec_to_bcd(b_dec)
        
        # Set inputs
        dut.a.value = a_bcd
        dut.b.value = b_bcd
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=100)
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error("  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")