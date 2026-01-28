import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_prince_of_python(dut):
    """Test the prince_of_python module with sample input."""
    
    # Detect if sequential (has clk)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Set inputs for test case (n=3)
    # Level 0
    dut.x_0.value = 1
    dut.s_0.value = 1
    dut.a_0_0.value = 40
    dut.a_0_1.value = 30
    dut.a_0_2.value = 20
    dut.a_0_3.value = 10
    # Level 1
    dut.x_1.value = 3
    dut.s_1.value = 1
    dut.a_1_0.value = 95
    dut.a_1_1.value = 95
    dut.a_1_2.value = 95
    dut.a_1_3.value = 10
    # Level 2
    dut.x_2.value = 2
    dut.s_2.value = 1
    dut.a_2_0.value = 95
    dut.a_2_1.value = 50
    dut.a_2_2.value = 30
    dut.a_2_3.value = 20
    
    # Wait for inputs to stabilize
    await Timer(10, units='ns')
    
    if is_sequential:
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(1000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
    else:
        # Combinational - wait for propagation
        await Timer(100, units='ns')
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result = int(dut.result.value)
    expected = 91
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    dut._log.info(f"Test passed: result = {result}")