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
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4  # Each digit is 4 bits (0-9)
MAX_N = 16      # Maximum number of digits
MAX_K = 8       # Maximum pattern length
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_digits_array(dut, values):
    """Write digits to the input array."""
    for i in range(MAX_N):
        if i < len(values):
            dut.digits[i].value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            dut.digits[i].value = 0

async def read_output_array(dut, n):
    """Read output digits array."""
    results = []
    for i in range(n):
        if is_value_defined(dut.y_digits[i].value):
            results.append(int(dut.y_digits[i].value))
        else:
            results.append(None)
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
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

async def start_computation(dut, n, k, digits):
    """Start computation with given inputs."""
    # Set inputs
    dut.n.value = n
    dut.k.value = k
    await write_digits_array(dut, digits)
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_beautiful_number(dut):
    """Test the beautiful number module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, k, input_digits, expected_output_digits, description)
    test_cases = [
        (3, 2, [3,5,3], [3,5,3], "Example 1: 353 with k=2"),
        (4, 2, [1,2,3,4], [1,3,1,3], "Example 2: 1234 with k=2"),
        (5, 4, [9,9,9,9,9], [9,9,9,9,9], "All 9s"),
        (5, 4, [4,1,2,4,2], [4,1,2,4,4], "Increment needed"),
        (5, 2, [1,6,1,6,1], [1,6,1,6,1], "Already beautiful"),
        (2, 1, [3,3], [3,3], "All same digits"),
        (2, 1, [9,9], [9,9], "All 9s with k=1"),
        (2, 1, [3,1], [3,3], "Needs increment"),
        (4, 2, [1,9,2,0], [2,0,2,0], "Edge case"),
        (6, 2, [3,3,3,4,2,3], [3,4,3,4,3,4], "Multiple increments needed"),
        (4, 3, [1,9,9,2], [2,0,0,2], "Pattern increment"),
        (5, 3, [1,8,9,2,0], [1,9,0,1,9], "From sample cases"),
        (5, 2, [1,6,1,3,7], [1,6,1,6,1], "From sample cases"),
        (5, 3, [9,1,4,7,1], [9,1,4,9,1], "From sample cases"),
        (5, 3, [9,1,4,9,1], [9,1,4,9,1], "From sample cases"),
        (5, 4, [4,1,2,4,2], [4,1,2,4,4], "From sample cases"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, input_digits, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Start computation
            await start_computation(dut, n, k, input_digits)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            result_digits = await read_output_array(dut, n)
            
            # Verify result length
            if not is_value_defined(dut.m.value):
                raise TestFailure("Output length m is undefined")
            
            m = int(dut.m.value)
            if m != n:
                raise TestFailure(f"Expected length {n}, got {m}")
            
            # Verify digits
            if result_digits != expected:
                raise TestFailure(f"Expected {expected}, got {result_digits}")
            
            cocotb.log.info(f"  PASS: Output = {result_digits}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
