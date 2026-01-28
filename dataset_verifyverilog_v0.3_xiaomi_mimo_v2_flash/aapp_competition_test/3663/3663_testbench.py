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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
RESULT_WIDTH = 24
MAX_N = 8
MAX_EDGES = 7
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width, max_size):
    """Write values to array, handling different interface styles."""
    values = values[:max_size]
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        # Zero out remaining elements
        for i in range(len(values), max_size):
            arr[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i in range(max_size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_army_movement(dut):
    """Test the army movement module with adapted test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, edges, x, y, expected_cost)
    # Edges: list of (u, v, cost)
    test_cases = [
        # Test case 1: n=3 (original example)
        (
            3,  # n
            [(1, 2, 5), (3, 1, 5)],  # edges
            [2, 5, 1],  # x
            [1, 0, 3],  # y
            15  # expected cost
        ),
        # Test case 2: n=6
        (
            6,
            [(1, 2, 2), (1, 3, 5), (1, 4, 1), (2, 5, 5), (2, 6, 1)],
            [0, 1, 2, 2, 0, 0],
            [0, 0, 1, 1, 1, 1],
            9
        ),
        # Test case 3: Simple 2-node tree
        (
            2,
            [(1, 2, 3)],
            [5, 0],
            [2, 3],
            9
        ),
        # Test case 4: Single node
        (
            1,
            [],
            [10],
            [5],
            0
        ),
        # Test case 5: No movement needed
        (
            3,
            [(1, 2, 10), (1, 3, 20)],
            [1, 2, 3],
            [1, 2, 3],
            0
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, edges, x_vals, y_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: n={n}, expected={expected}")
        
        try:
            # Convert to 0-indexed
            edges_0 = [(u-1, v-1, c) for u, v, c in edges]
            
            # Write n
            dut.n.value = n
            
            # Write edges (pad to MAX_EDGES)
            edge_u = [e[0] for e in edges_0] + [0] * (MAX_EDGES - len(edges_0))
            edge_v = [e[1] for e in edges_0] + [0] * (MAX_EDGES - len(edges_0))
            edge_cost = [e[2] for e in edges_0] + [0] * (MAX_EDGES - len(edges_0))
            
            await write_array(dut, 'edge_u', edge_u, DATA_WIDTH, MAX_EDGES)
            await write_array(dut, 'edge_v', edge_v, DATA_WIDTH, MAX_EDGES)
            await write_array(dut, 'edge_cost', edge_cost, DATA_WIDTH, MAX_EDGES)
            
            # Write x and y (pad to MAX_N)
            x_padded = x_vals + [0] * (MAX_N - len(x_vals))
            y_padded = y_vals + [0] * (MAX_N - len(y_vals))
            await write_array(dut, 'x', x_padded, DATA_WIDTH, MAX_N)
            await write_array(dut, 'y', y_padded, DATA_WIDTH, MAX_N)
            
            # Wait a bit for combinational logic
            await Timer(100, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=200)
            
            # Read result
            if not is_value_defined(dut.total_cost.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.total_cost.value)
            
            # Check against expected
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset before next test
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")