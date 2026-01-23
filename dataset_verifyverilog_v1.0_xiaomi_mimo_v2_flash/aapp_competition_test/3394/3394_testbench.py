import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
NODE_WIDTH = 4
MAX_N = 8
MAX_M = 16
MAX_K = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000

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
# ARRAY WRITE HELPERS
# ============================================================================
async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first (e.g., dut.edge_u[i])
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (array_name_0, array_name_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_result(dut):
    """Read result signal with safety check."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

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
# TEST CASES
# ============================================================================
test_cases = [
    {
        "name": "Sample 1",
        "n": 4,
        "m": 4,
        "k": 3,
        "edges": [
            (1, 2, 2),
            (2, 3, 4),
            (3, 4, 1),
            (4, 1, 2)
        ],
        "orders": [
            (1, 4, 2),
            (3, 3, 3),
            (4, 3, 6)
        ],
        "expected": 6
    },
    {
        "name": "Sample 2",
        "n": 3,
        "m": 2,
        "k": 4,
        "edges": [
            (1, 2, 1),
            (3, 2, 2)
        ],
        "orders": [
            (0, 3, 1),
            (1, 3, 3),
            (2, 2, 4),
            (4, 3, 6)
        ],
        "expected": 8
    }
]

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pizza_delivery_optimizer(dut):
    """Test the PizzaDeliveryOptimizer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Running {tc['name']}...")
        
        try:
            # Write n, m, k
            if has_signal(dut, 'n'):
                dut.n.value = tc['n']
            if has_signal(dut, 'm'):
                dut.m.value = tc['m']
            if has_signal(dut, 'k'):
                dut.k.value = tc['k']
            
            # Write edges
            edge_u_vals = [e[0] for e in tc['edges']]
            edge_v_vals = [e[1] for e in tc['edges']]
            edge_d_vals = [e[2] for e in tc['edges']]
            
            await write_array(dut, 'edge_u', edge_u_vals, NODE_WIDTH)
            await write_array(dut, 'edge_v', edge_v_vals, NODE_WIDTH)
            await write_array(dut, 'edge_d', edge_d_vals, DATA_WIDTH)
            
            # Write orders
            order_s_vals = [o[0] for o in tc['orders']]
            order_u_vals = [o[1] for o in tc['orders']]
            order_t_vals = [o[2] for o in tc['orders']]
            
            await write_array(dut, 'order_s', order_s_vals, DATA_WIDTH)
            await write_array(dut, 'order_u', order_u_vals, NODE_WIDTH)
            await write_array(dut, 'order_t', order_t_vals, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")