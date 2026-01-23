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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hexagon_triangles(dut):
    """Test the hexagon triangles module."""
    
    # Detect if sequential (has clock)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ([1, 1, 1, 1, 1, 1], 6, "Sample 1"),
        ([1, 2, 1, 2, 1, 2], 13, "Sample 2"),
        ([2, 4, 5, 3, 3, 6], 83, "Test 3"),
        ([45, 19, 48, 18, 46, 21], 6099, "Test 4"),
        ([66, 6, 65, 6, 66, 5], 5832, "Test 5"),
        ([7, 5, 4, 8, 4, 5], 175, "Test 6"),
        ([3, 2, 1, 4, 1, 2], 25, "Test 7"),
        ([7, 1, 7, 3, 5, 3], 102, "Test 8"),
        ([9, 2, 9, 3, 8, 3], 174, "Test 9"),
        ([1, 6, 1, 5, 2, 5], 58, "Test 10"),
        ([41, 64, 48, 61, 44, 68], 17488, "Test 11"),
        ([1, 59, 2, 59, 1, 60], 3838, "Test 12"),
        ([30, 36, 36, 32, 34, 38], 7052, "Test 13"),
        ([50, 40, 46, 38, 52, 34], 11176, "Test 14"),
        ([4, 60, 4, 60, 4, 60], 4576, "Test 15"),
        ([718, 466, 729, 470, 714, 481], 2102808, "Test 16"),
        ([131, 425, 143, 461, 95, 473], 441966, "Test 17"),
        ([125, 7, 128, 8, 124, 11], 20215, "Test 18"),
        ([677, 303, 685, 288, 692, 296], 1365807, "Test 19"),
        ([1, 577, 7, 576, 2, 582], 342171, "Test 20"),
        ([1000, 1000, 1000, 1000, 1000, 1000], 6000000, "Test 21"),
        ([1, 1, 1000, 1, 1, 1000], 4002, "Test 22"),
        ([1000, 1000, 1, 1000, 1000, 1], 2004000, "Test 23"),
        ([1000, 1, 1000, 999, 2, 999], 2003997, "Test 24"),
        ([1, 1000, 1, 1, 1000, 1], 4002, "Test 25"),
        ([888, 888, 888, 887, 889, 887], 4729487, "Test 26"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Write inputs to DUT
        if has_signal(dut, 'a1'):
            dut.a1.value = inputs[0]
            dut.a2.value = inputs[1]
            dut.a3.value = inputs[2]
            dut.a4.value = inputs[3]
            dut.a5.value = inputs[4]
            dut.a6.value = inputs[5]
        else:
            raise TestFailure("Input signals not found")
        
        # Wait for propagation
        if is_sequential:
            # Wait two cycles (though not needed for combinational)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        else:
            # Combinational: small delay
            await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) for test {i+1}")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")