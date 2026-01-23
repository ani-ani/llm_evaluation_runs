import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
N_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lucky_permutation_triple(dut):
    """Test the Lucky Permutation Triple module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (n, description)
    test_cases = [
        (1, "n=1 (odd)"),
        (2, "n=2 (even)"),
        (3, "n=3 (odd)"),
        (4, "n=4 (even)"),
        (5, "n=5 (odd)"),
        (6, "n=6 (even)"),
        (7, "n=7 (odd)"),
        (8, "n=8 (even)"),
        (0, "n=0 (invalid)"),
        (9, "n=9 (odd, but >8)"),
    ]
    
    passed = 0
    failed = 0
    
    for n, description in test_cases:
        cocotb.log.info(f"Test: {description}")
        
        try:
            # Write n (4 bits)
            dut.n.value = clamp_to_width(n, N_WIDTH)
            
            # Start computation
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read valid flag
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal is undefined (X/Z)")
            
            valid = int(dut.valid.value)
            
            # Determine expected valid
            expected_valid = 1 if (n > 0 and n <= 8 and n % 2 == 1) else 0
            
            if valid != expected_valid:
                raise TestFailure(f"Valid mismatch: expected {expected_valid}, got {valid}")
            
            # If valid, check permutations
            if valid:
                # Read arrays
                a_vals = await read_array(dut, 'a', n)
                b_vals = await read_array(dut, 'b', n)
                c_vals = await read_array(dut, 'c', n)
                
                # Compute expected values
                expected_a = list(range(n))
                expected_b = list(range(n))
                expected_c = [(2 * i) % n for i in range(n)]
                
                # Compare
                if a_vals != expected_a:
                    raise TestFailure(f"a mismatch: expected {expected_a}, got {a_vals}")
                if b_vals != expected_b:
                    raise TestFailure(f"b mismatch: expected {expected_b}, got {b_vals}")
                if c_vals != expected_c:
                    raise TestFailure(f"c mismatch: expected {expected_c}, got {c_vals}")
                
                cocotb.log.info(f"  PASS: valid=1, arrays correct")
            else:
                cocotb.log.info(f"  PASS: valid=0 (expected)")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
