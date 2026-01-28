import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 16
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# BELT ENCODING HELPERS
# ============================================================================

def encode_belt(c):
    """Convert belt character to 2-bit encoding."""
    if c == '-':
        return 0b00
    elif c == '>':
        return 0b01
    elif c == '<':
        return 0b10
    else:
        raise ValueError(f"Invalid belt character: {c}")

def pack_belts(s):
    """Pack belt string into 32-bit integer."""
    packed = 0
    for i, c in enumerate(s):
        bits = encode_belt(c)
        packed |= (bits << (2 * i))
    return packed

def compute_expected(n, s):
    """Compute expected count in Python."""
    # Check if all belts are same direction
    has_gt = '>' in s
    has_lt = '<' in s
    
    if not has_gt or not has_lt:
        return n
    
    # Count returnable rooms
    count = 0
    for i in range(n):
        left_belt = s[(i - 1) % n]
        right_belt = s[i]
        if left_belt == '-' or right_belt == '-':
            count += 1
    return count

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
async def test_snake_exhibition(dut):
    """Test the snake exhibition module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, s, description)
    test_cases = [
        (4, "-><-", "Example from problem"),
        (5, ">>>>>", "All clockwise"),
        (3, "<--", "Mixed with off"),
        (2, "<>", "Opposite directions"),
        (2, ">>", "All same direction"),
        (2, "--", "All off"),
        (3, "->>", "Partial off"),
        (6, "<<->>-", "Six rooms mixed"),
        (8, "--><->--", "Eight rooms"),
        (1, "-", "Edge case: n=1"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, s, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {description} (n={n}, s='{s}')")
        
        # Skip invalid n (n must be >= 2, but we included n=1 for edge testing)
        if n < 2:
            cocotb.log.warning(f"  Skipping: n={n} < 2")
            continue
        
        # Skip if n > MAX_N
        if n > MAX_N:
            cocotb.log.warning(f"  Skipping: n={n} > MAX_N={MAX_N}")
            continue
        
        try:
            # Compute expected result
            expected = compute_expected(n, s)
            
            # Pack belts
            packed_belts = pack_belts(s)
            
            # Set inputs
            dut.n.value = n
            dut.belts_packed.value = packed_belts
            dut.start.value = 0
            
            # Wait for next clock edge
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure(f"Count is undefined (X/Z)")
            
            result = int(dut.count.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: count = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
