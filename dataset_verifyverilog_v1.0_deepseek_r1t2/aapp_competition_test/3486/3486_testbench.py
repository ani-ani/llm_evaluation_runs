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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_hall_students(dut):
    """Test the hall_students module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (n0, n1, n2, n3, expected)
    test_cases = [
        (30, 3, 2, 45, 1),
        (3, 30, 2, 45, 3),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n0, n1, n2, n3, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: inputs = ({n0}, {n1}, {n2}, {n3}), expected = {expected}")
        
        # Set inputs
        dut.num0.value = n0
        dut.num1.value = n1
        dut.num2.value = n2
        dut.num3.value = n3
        
        # Pulse start
        if is_sequential:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done (should be high in this cycle)
            await Timer(1, units='ns')
            if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                raise TestFailure(f"Test {i+1}: Done not high after start")
        else:
            # Combinational module - just wait for propagation
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
        
        result = int(dut.result.value)
        if result != expected:
            dut._log.error(f"Test {i+1}: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
        
        # Wait for next cycle before next test
        if is_sequential:
            await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")