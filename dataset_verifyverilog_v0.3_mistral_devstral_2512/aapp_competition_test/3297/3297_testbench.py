import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

MAX_PUZZLE_LEN = 20
CLK_PERIOD_NS = 10
TIMEOUT_CYCLES = 10000

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cryptarithm_solver(dut):
    """Test the cryptarithm solver module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.puzzle_valid.value = 0
    dut.puzzle_char.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("SEND+MORE=MONEY", "9567+1085=10652"),
        ("A+A=A", "impossible"),
        ("C+B=A", "2+1=3"),
    ]
    
    for puzzle, expected in test_cases:
        cocotb.log.info(f"Testing: {puzzle}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed puzzle characters
        for i, char in enumerate(puzzle):
            await RisingEdge(dut.clk)
            dut.puzzle_char.value = ord(char)
            dut.puzzle_valid.value = 1
            
            # Wait for state machine to process
            await Timer(100, units='ns')
        
        # Signal end of puzzle
        await RisingEdge(dut.clk)
        dut.puzzle_valid.value = 0
        
        # Wait for computation with timeout
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > TIMEOUT_CYCLES:
                raise TestFailure(f"Timeout for puzzle {puzzle}")
        
        # Read result
        await RisingEdge(dut.clk)  # Result should be ready
        
        if expected == "impossible":
            if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
                cocotb.log.info(f"  PASS: Correctly identified as impossible")
            else:
                raise TestFailure(f"  FAIL: Should be impossible but got solution")
        else:
            # Read output characters
            output_chars = []
            for i in range(MAX_PUZZLE_LEN):
                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                    char_val = int(dut.result_char.value)
                    if char_val != 0:
                        output_chars.append(chr(char_val))
                await RisingEdge(dut.clk)
            
            actual_output = ''.join(output_chars)
            
            if actual_output == expected:
                cocotb.log.info(f"  PASS: {actual_output}")
            else:
                raise TestFailure(f"  FAIL: Expected {expected}, got {actual_output}")

    cocotb.log.info("All tests completed!")
