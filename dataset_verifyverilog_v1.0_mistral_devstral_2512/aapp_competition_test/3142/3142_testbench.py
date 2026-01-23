import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4      # 4 bits per digit
ARRAY_SIZE = 8      # 8 digits
RESULT_WIDTH = 16   # Count output width
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

# Packed array conversion
def to_32bit_packed(n):
    """Convert integer to 32-bit packed representation (8 digits, 4 bits each)."""
    if n < 0:
        return 0
    digits = []
    for i in range(8):
        digits.append(n % 10)
        n //= 10
    packed = 0
    for i in range(8):
        packed |= (digits[i] << (i * 4))
    return packed

def from_32bit_packed(packed):
    """Convert 32-bit packed representation to integer."""
    n = 0
    for i in range(8):
        digit = (packed >> (i * 4)) & 0xF
        n += digit * (10 ** i)
    return n

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
async def test_top_module(dut):
    """Test the top module with scaled examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (A, B, S, expected_count, expected_candidate)
    test_cases = [
        (1, 9, 5, 1, 5),
        (1, 100, 10, 9, 19),
        (11111, 99999, 24, 5445, 11499),
    ]
    
    passed = 0
    failed = 0
    
    for i, (A_val, B_val, S_val, expected_count, expected_candidate) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: A={A_val}, B={B_val}, S={S_val}")
        
        try:
            # Convert to packed representation
            A_packed = to_32bit_packed(A_val)
            B_packed = to_32bit_packed(B_val)
            expected_candidate_packed = to_32bit_packed(expected_candidate)
            
            # Set inputs
            dut.A.value = A_packed
            dut.B.value = B_packed
            dut.S.value = S_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.count.value):
                raise TestFailure("Count output is undefined (X/Z)")
            
            if not is_value_defined(dut.candidate.value):
                raise TestFailure("Candidate output is undefined (X/Z)")
            
            count = int(dut.count.value)
            candidate_packed = int(dut.candidate.value)
            candidate = from_32bit_packed(candidate_packed)
            
            # Verify results
            if count != expected_count:
                raise TestFailure(f"Count mismatch: expected {expected_count}, got {count}")
            
            if candidate != expected_candidate:
                raise TestFailure(f"Candidate mismatch: expected {expected_candidate}, got {candidate}")
            
            cocotb.log.info(f"  PASS: count={count}, candidate={candidate}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")