import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4
DATA_WIDTH = 8
SUM_WIDTH = 9
SIZE_WIDTH = 8
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
# MATRIX SETTER
# ============================================================================

async def set_matrices(dut, h_matrix, v_matrix):
    """Set h and v matrices through individual ports."""
    for i in range(N):
        for j in range(N):
            # Set h
            h_port_name = f"h_{i}{j}"
            if has_signal(dut, h_port_name):
                h_val = clamp_to_width(h_matrix[i][j], DATA_WIDTH)
                getattr(dut, h_port_name).value = h_val
            else:
                raise TestFailure(f"Port {h_port_name} not found")
            
            # Set v
            v_port_name = f"v_{i}{j}"
            if has_signal(dut, v_port_name):
                v_val = clamp_to_width(v_matrix[i][j], DATA_WIDTH)
                getattr(dut, v_port_name).value = v_val
            else:
                raise TestFailure(f"Port {v_port_name} not found")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_largest_connected_component(dut):
    """Test the largest_connected_component module."""
    
    # Detect if sequential (has clk)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (h_matrix, v_matrix, expected_max_size, description)
    # h and v are 4x4 matrices of integers (0-255)
    test_cases = [
        # Test case 1: All cells same h and v -> all sums equal -> component size 16
        (
            [[10]*4 for _ in range(4)],
            [[5]*4 for _ in range(4)],
            16,
            "All cells same sum"
        ),
        # Test case 2: 2x2 block top-left with same sum, rest different
        # Top-left 2x2: h=1, v=2 -> sum=3
        # Others: h=5, v=5 -> sum=10
        (
            [[1, 1, 5, 5],
             [1, 1, 5, 5],
             [5, 5, 5, 5],
             [5, 5, 5, 5]],
            [[2, 2, 5, 5],
             [2, 2, 5, 5],
             [5, 5, 5, 5],
             [5, 5, 5, 5]],
            4,
            "2x2 block and isolated cells"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (h_matrix, v_matrix, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Set input matrices
            await set_matrices(dut, h_matrix, v_matrix)
            
            # Wait a bit for inputs to stabilize (combinational logic)
            await Timer(100, units='ns')
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read max_size
            if not is_value_defined(dut.max_size.value):
                raise TestFailure(f"max_size is undefined (X/Z)")
            
            result = int(dut.max_size.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: max_size = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")