import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_kernel_area(dut):
    """Main test function for kernel_area module."""
    
    # Initialize control signals
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'n'):
        dut.n.value = 0
    
    # Initialize all array elements to zero
    for i in range(8):
        if has_signal(dut, f'x_{i}'):
            getattr(dut, f'x_{i}').value = 0
        elif has_signal(dut, f'x[{i}]'):
            dut.x[i].value = 0
        if has_signal(dut, f'y_{i}'):
            getattr(dut, f'y_{i}').value = 0
        elif has_signal(dut, f'y[{i}]'):
            dut.y[i].value = 0
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Release reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, vertices (scaled by 100), expected area (scaled by 10000))
    test_cases = []
    
    # Case 1: Square (0,0), (100,0), (100,100), (0,100) -> area = 10000
    test_cases.append((4, [(0,0), (100,0), (100,100), (0,100)], 10000))
    
    # Case 2: Triangle (0,0), (100,0), (0,100) -> area = 5000
    test_cases.append((3, [(0,0), (100,0), (0,100)], 5000))
    
    # Case 3: Regular hexagon (side=0.5, scaled by 100)
    side = 0.5
    hex_vertices = []
    for i in range(6):
        angle = math.radians(60 * i)
        x = side * math.cos(angle)
        y = side * math.sin(angle)
        hex_vertices.append((int(round(x*100)), int(round(y*100))))
    area_hex = 0.5 * side**2 * 3 * math.sqrt(3)  # exact area
    expected_hex = int(round(area_hex * 10000))
    test_cases.append((6, hex_vertices, expected_hex))
    
    # Run each test case
    for i, (n, vertices, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n}, vertices={vertices}, expected={expected}")
        
        # Set number of vertices
        if has_signal(dut, 'n'):
            dut.n.value = n
        
        # Set vertex coordinates
        for idx, (x_val, y_val) in enumerate(vertices):
            # Validate range (32-bit signed)
            if x_val > 2**31-1 or x_val < -2**31:
                raise ValueError(f"x_val {x_val} out of 32-bit range")
            if y_val > 2**31-1 or y_val < -2**31:
                raise ValueError(f"y_val {y_val} out of 32-bit range")
            
            # Assign x
            if has_signal(dut, f'x_{idx}'):
                getattr(dut, f'x_{idx}').value = x_val
            elif has_signal(dut, f'x[{idx}]'):
                dut.x[idx].value = x_val
            else:
                try:
                    dut.x[idx].value = x_val
                except (AttributeError, TypeError):
                    raise TestFailure(f"Cannot find x[{idx}]")
            
            # Assign y
            if has_signal(dut, f'y_{idx}'):
                getattr(dut, f'y_{idx}').value = y_val
            elif has_signal(dut, f'y[{idx}]'):
                dut.y[idx].value = y_val
            else:
                try:
                    dut.y[idx].value = y_val
                except (AttributeError, TypeError):
                    raise TestFailure(f"Cannot find y[{idx}]")
        
        # Wait for inputs to settle
        await Timer(100, units='ns')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for next clock edge to capture done and area
        await RisingEdge(dut.clk)
        
        # Verify done signal
        if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
            raise TestFailure(f"Test {i+1}: done not asserted")
        
        # Read and verify area
        if not is_value_defined(dut.area.value):
            raise TestFailure(f"Test {i+1}: area is undefined")
        
        area_actual = int(dut.area.value)
        if area_actual != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {area_actual}")
        
        dut._log.info(f"Test {i+1} passed")
    
    dut._log.info("All tests passed")