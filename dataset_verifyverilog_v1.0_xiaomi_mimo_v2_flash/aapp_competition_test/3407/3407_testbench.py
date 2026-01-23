import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# FIXED‑POINT CONVERSION FOR COORDINATES
# ============================================================================

Q16_16_SCALE = 1 << 16

def float_to_fixed(f):
    """Convert float to Q16.16 fixed‑point integer."""
    return int(f * Q16_16_SCALE)

def fixed_to_float(fixed):
    """Convert Q16.16 fixed‑point integer to float."""
    return fixed / Q16_16_SCALE

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tree_embedder(dut):
    """Test tree embedding for the two sample trees."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, edges, expected_coords)
    # edges is a list of (a, b) pairs
    # expected_coords is a list of (x, y) floats for nodes 1..n
    # Note: Verilog uses 0‑based indexing internally; we map accordingly.
    test_cases = [
        # Sample 1: star tree
        (
            5,
            [(1,2), (1,3), (1,4), (1,5)],
            [
                (0.0, 0.0),
                (1.0, 0.0),
                (-1.0, 0.0),
                (0.0, 1.0),
                (0.0, -1.0)
            ]
        ),
        # Sample 2: chain with branch
        (
            5,
            [(2,1), (3,1), (2,4), (2,5)],
            [
                (40.0, 40.0),
                (40.7071067812, 40.7071067812),
                (41.0, 40.0),
                (41.7071067812, 40.7071067812),
                (40.0, 41.4142135624)
            ]
        )
    ]
    
    for case_idx, (n, edges, expected_coords) in enumerate(test_cases):
        dut._log.info(f"\nTest case {case_idx+1}: n={n}, edges={edges}")
        
        # Prepare edge arrays
        edge_valid = 0
        edge_a = [0]*7
        edge_b = [0]*7
        for i, (a, b) in enumerate(edges):
            edge_valid |= (1 << i)
            edge_a[i] = a
            edge_b[i] = b
        
        # Assign inputs
        dut.n.value = n
        dut.edge_valid.value = edge_valid
        for i in range(7):
            dut.edge_a[i].value = edge_a[i]
            dut.edge_b[i].value = edge_b[i]
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read coordinates
        # Verilog outputs x[0..7], y[0..7] (0‑based nodes)
        # We need to map node index: node 1 -> index 0, etc.
        for node in range(1, n+1):
            idx = node - 1
            if not is_value_defined(dut.x[idx].value) or not is_value_defined(dut.y[idx].value):
                raise TestFailure(f"Node {node} output undefined (X/Z)")
            
            x_fixed = int(dut.x[idx].value)
            y_fixed = int(dut.y[idx].value)
            x_float = fixed_to_float(x_fixed)
            y_float = fixed_to_float(y_fixed)
            
            exp_x, exp_y = expected_coords[idx]
            
            # Check absolute error <= 1e-6
            if abs(x_float - exp_x) > 1e-6 or abs(y_float - exp_y) > 1e-6:
                raise TestFailure(
                    f"Node {node}: expected ({exp_x:.10f}, {exp_y:.10f}), "
                    f"got ({x_float:.10f}, {y_float:.10f})"
                )
            
            dut._log.info(f"  Node {node}: ({x_float:.10f}, {y_float:.10f})")
        
        dut._log.info(f"  PASS")
    
    dut._log.info("\n" + "="*50)
    dut._log.info("All tests passed")
