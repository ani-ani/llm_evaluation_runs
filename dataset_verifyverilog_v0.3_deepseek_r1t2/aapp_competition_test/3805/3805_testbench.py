import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
DATA_WIDTH = 1
MAX_LENGTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# TESTBENCH FOR WIRE UNTANGLING PROBLEM
# ============================================================================

async def send_sequence(dut, sequence):
    """Send a sequence of characters to the DUT."""
    for i, char in enumerate(sequence):
        # Convert character to bit: '+' -> 1, '-' -> 0
        char_bit = 1 if char == '+' else 0
        dut.char_in.value = char_bit
        dut.valid_in.value = 1
        dut.last.value = 1 if i == len(sequence) - 1 else 0
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        dut.last.value = 0
    
    # Wait for done signal
    await wait_for_done(dut)

# Python reference implementation
def python_reference(sequence):
    """Reference implementation in Python."""
    stack = []
    for char in sequence:
        if stack and stack[-1] == char:
            stack.pop()
        else:
            stack.append(char)
    return len(stack) == 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wire_untangle(dut):
    """Main test function for wire untangling module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Define test cases: (input_sequence, expected_result)
    test_cases = [
        ("-++-", True),   # Example 1
        ("+-", False),    # Example 2
        ("++", True),     # Example 3
        ("-", False),     # Example 4
        ("-+-", False),   # Additional test
        ("--", True),     # Additional test
        ("+-+", False),   # Additional test
        ("", True),       # Edge case: empty string
        ("++++", True),   # Multiple same
        ("+-+-", False),  # Alternating
        ("++--", True),   # Pair cancellation
        ("++-+--", False), # Complex case
        ("+-+--", False),  # Additional
        ("---", False),   # Three same
        ("++-", True),    # Mix
        ("-++", True),    # Mix
    ]
    
    passed = 0
    failed = 0
    
    for i, (sequence, expected) in enumerate(test_cases):
        if len(sequence) > MAX_LENGTH:
            cocotb.log.warning(f"Test {i+1}: Sequence too long ({len(sequence)} > {MAX_LENGTH}), skipping")
            continue
        
        cocotb.log.info(f"Test {i+1}: Sequence '{sequence}' -> Expected: {'Yes' if expected else 'No'}")
        
        try:
            # Compute expected using reference
            ref_result = python_reference(sequence)
            if ref_result != expected:
                cocotb.log.error(f"  Test case error: reference gives {ref_result}, expected {expected}")
                failed += 1
                continue
            
            # Send sequence to DUT
            await send_sequence(dut, sequence)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            dut_result = int(dut.result.value) == 1
            
            # Verify result
            if dut_result != expected:
                raise TestFailure(f"Expected {'Yes' if expected else 'No'}, got {'Yes' if dut_result else 'No'}")
            
            cocotb.log.info(f"  PASS: result = {'Yes' if dut_result else 'No'}")
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