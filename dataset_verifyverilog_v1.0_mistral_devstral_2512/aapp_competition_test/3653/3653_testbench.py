import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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

async def wait_for_done(dut, max_cycles=10000):
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
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def compute_distance(x1, y1, x2, y2):
    """Compute distance from origin to line through (x1,y1) and (x2,y2)."""
    a = y2 - y1
    b = x1 - x2
    c = x2 * y1 - x1 * y2
    denom = math.sqrt(a * a + b * b)
    d = abs(c) / denom
    return d

def accessible_area(R, d):
    """Compute area accessible to dog on lawn side."""
    if d >= R:
        return math.pi * R * R
    else:
        # Area = πR² - R²*arccos(d/R) + d*sqrt(R²-d²)
        theta = math.acos(d / R)
        return math.pi * R * R - R * R * theta + d * math.sqrt(R * R - d * d)

def find_min_chain_length(L, x1, y1, x2, y2):
    """Find minimum integer R such that accessible area >= L."""
    d = compute_distance(x1, y1, x2, y2)
    for R in range(1, 201):
        area = accessible_area(R, d)
        if area >= L:
            return R
    return 200

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dog_chain(dut):
    """Test the dog_chain module with provided examples."""
    
    # Configure based on your DUT
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        {"L": 4, "x1": -10, "y1": 0, "x2": -10, "y2": 10, "expected": 2},
        {"L": 314, "x1": 100, "y1": 100, "x2": -100, "y2": -100, "expected": 15},
    ]
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: L={tc['L']}, wall from ({tc['x1']},{tc['y1']}) to ({tc['x2']},{tc['y2']})")
        
        # Compute expected using Python reference
        expected = find_min_chain_length(tc['L'], tc['x1'], tc['y1'], tc['x2'], tc['y2'])
        cocotb.log.info(f"  Expected R: {expected}")
        
        # Provide inputs
        dut.L.value = tc['L']
        dut.x1.value = from_signed(tc['x1'], 16)
        dut.y1.value = from_signed(tc['y1'], 16)
        dut.x2.value = from_signed(tc['x2'], 16)
        dut.y2.value = from_signed(tc['y2'], 16)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=100000)
        
        # Read result
        if not is_value_defined(dut.R.value):
            raise TestFailure(f"Test {i+1}: Result R is undefined (X/Z)")
        
        actual = int(dut.R.value)
        
        if actual != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {actual}")
        
        cocotb.log.info(f"  PASS: R={actual}")
        
        # Wait a few cycles before next test
        for _ in range(5):
            await RisingEdge(dut.clk)
    
    cocotb.log.info("All tests passed!")
