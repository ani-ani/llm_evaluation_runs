import cocotb
from cocotb.triggers import Timer
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_triangle_areas(dut):
    """Test triangle area calculation."""
    
    # Test case 1: N=4 points
    dut.N.value = 4
    x = [2, 0, -2, 0]
    y = [0, 2, 0, -2]
    
    # Write points individually
    for i in range(4):
        dut.x[i].value = x[i]
        dut.y[i].value = y[i]
    
    # Wait for combinational logic to settle
    await Timer(100, units='ns')
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result1 = int(dut.result.value)
    expected1 = 32  # Sum of twice area of all triangles
    
    if result1 != expected1:
        raise TestFailure(f"Test 1 failed: expected {expected1}, got {result1}")
    
    dut._log.info(f"Test 1 passed: result = {result1}")
    
    # Test case 2: N=5 points
    dut.N.value = 5
    x = [2, 0, -2, 0, 2]
    y = [0, 2, 0, -2, 2]
    
    for i in range(5):
        dut.x[i].value = x[i]
        dut.y[i].value = y[i]
    
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result2 = int(dut.result.value)
    expected2 = 72
    
    if result2 != expected2:
        raise TestFailure(f"Test 2 failed: expected {expected2}, got {result2}")
    
    dut._log.info(f"Test 2 passed: result = {result2}")
    
    # Test case 3: N=3 points
    dut.N.value = 3
    x = [0, 1, 0]
    y = [0, 0, 1]
    
    for i in range(3):
        dut.x[i].value = x[i]
        dut.y[i].value = y[i]
    
    await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result3 = int(dut.result.value)
    expected3 = 2  # |(1-0)*(1-0) - (0-0)*(0-0)| = 1*1 - 0 = 1, twice = 2
    
    if result3 != expected3:
        raise TestFailure(f"Test 3 failed: expected {expected3}, got {result3}")
    
    dut._log.info(f"Test 3 passed: result = {result3}")
    
    dut._log.info("All tests passed!")