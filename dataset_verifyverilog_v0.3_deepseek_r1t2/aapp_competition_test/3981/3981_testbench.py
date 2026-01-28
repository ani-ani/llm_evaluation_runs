import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_VERTICES = 4
CLK_PERIOD_NS = 10

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
# POLYGON ASSIGNMENT HELPERS
# ============================================================================
def assign_polygon(dut, prefix, size, vertices):
    """Assign polygon to DUT signals.
    prefix: 'a' or 'b'
    size: 2,3,4
    vertices: list of (x,y) tuples, length <=4
    """
    # Set size
    size_signal = getattr(dut, f'size_{prefix}')
    size_signal.value = size
    # Assign vertices
    for i in range(MAX_VERTICES):
        x_name = f'{prefix}x{i}'
        y_name = f'{prefix}y{i}'
        if i < len(vertices):
            x_val = clamp_to_width(vertices[i][0], DATA_WIDTH)
            y_val = clamp_to_width(vertices[i][1], DATA_WIDTH)
            getattr(dut, x_name).value = x_val
            getattr(dut, y_name).value = y_val
        else:
            # Unused vertices, set to 0
            getattr(dut, x_name).value = 0
            getattr(dut, y_name).value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_safe_rocket(dut):
    """Test the safe_rocket module."""
    
    # Detect required signals
    if not has_signal(dut, 'size_a') or not has_signal(dut, 'safe'):
        raise TestFailure("Required signals not found")
    
    # Test cases: (size_a, vertices_a, size_b, vertices_b, expected_safe, description)
    test_cases = [
        # Case 1: Identical triangles
        (3, [(0,0),(2,0),(0,2)], 3, [(0,0),(2,0),(0,2)], 1, "Identical triangles"),
        # Case 2: Congruent triangles, different vertices
        (3, [(0,0),(2,0),(0,2)], 3, [(0,0),(2,0),(2,2)], 1, "Congruent triangles (both CCW)"),
        # Case 3: Non-congruent triangles
        (3, [(0,0),(2,0),(0,2)], 3, [(0,0),(3,0),(0,4)], 0, "Non-congruent triangles"),
        # Case 4: Congruent squares (axis vs rotated)
        (4, [(0,0),(2,0),(2,2),(0,2)], 4, [(1,0),(2,1),(1,2),(0,1)], 1, "Congruent squares"),
        # Case 5: Collinear segments (size 2)
        (2, [(0,0),(5,0)], 2, [(0,0),(0,5)], 1, "Collinear segments same length"),
        # Case 6: Collinear segments different lengths
        (2, [(0,0),(5,0)], 2, [(0,0),(6,0)], 0, "Collinear segments different length"),
        # Case 7: Size mismatch
        (3, [(0,0),(2,0),(0,2)], 4, [(0,0),(2,0),(2,2),(0,2)], 0, "Size mismatch"),
        # Case 8: Mirror image triangles (opposite orientation)
        (3, [(0,0),(2,0),(0,2)], 3, [(0,2),(2,2),(2,0)], 0, "Mirror image triangles"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (size_a, vertices_a, size_b, vertices_b, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Assign inputs
            assign_polygon(dut, 'a', size_a, vertices_a)
            assign_polygon(dut, 'b', size_b, vertices_b)
            
            # Wait for combinational propagation
            await Timer(100, units='ns')
            
            # Read output
            if not is_value_defined(dut.safe.value):
                raise TestFailure("Output 'safe' is undefined (X/Z)")
            
            result = safe_int(dut.safe.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: safe = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")