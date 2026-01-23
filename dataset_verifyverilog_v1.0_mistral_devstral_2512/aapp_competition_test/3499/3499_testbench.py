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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_palindrome_count(dut):
    """Test the palindrome_count module with N=2."""
    
    # Detect signals
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_S = has_signal(dut, 'S')
    has_result = has_signal(dut, 'result')
    has_done = has_signal(dut, 'done')
    
    if not (has_clk and has_rst and has_start and has_S and has_result and has_done):
        dut._log.error("Missing expected signals")
        raise TestFailure("DUT missing required signals")
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.S.value = 0
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases for N=2, alphabet {A,B}, A=0, B=1
    # S is a packed vector: bit i corresponds to character i
    test_cases = [
        ("AA", 3),  # S='AA' -> bits 00, expected 3
        ("AB", 2),  # S='AB' -> bits 10 (since bit0=A=0, bit1=B=1 -> 2'b10 = 2)
    ]
    
    for s_str, expected in test_cases:
        # Convert string to packed integer
        N = 2
        s_val = 0
        for i, char in enumerate(s_str):
            if char == 'B':
                s_val |= (1 << i)  # bit i = 1 for B
        
        # Assign S
        dut.S.value = s_val
        dut._log.info(f"Testing S='{s_str}' (val={s_val}), expected={expected}")
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        timeout_cycles = 1000
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done for S={s_str}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined for S={s_str}")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"S='{s_str}': expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result={result}")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed")