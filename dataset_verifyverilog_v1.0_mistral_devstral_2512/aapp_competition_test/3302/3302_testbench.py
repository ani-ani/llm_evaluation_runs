import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4          # 4-bit values for n=4
MAX_N = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

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
# APPLICATION-SPECIFIC HELPER FUNCTIONS
# ============================================================================

def calculate_hamming(a, b, n):
    """Calculate Hamming distance between two n-bit integers."""
    xor = a ^ b
    dist = 0
    for i in range(n):
        if xor & (1 << i):
            dist += 1
    return dist

def is_valid_sequence(seq, n, p_mask):
    """Check if sequence is valid color code."""
    if len(seq) != (1 << n):
        return False
    
    # Check all values are unique
    if len(set(seq)) != len(seq):
        return False
    
    # Check consecutive pairs
    for i in range(len(seq) - 1):
        dist = calculate_hamming(seq[i], seq[i+1], n)
        if dist == 0 or dist > 4:
            return False
        if not (p_mask & (1 << (dist - 1))):
            return False
    
    return True

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

async def start_computation(dut, n, p_mask):
    """Start the module with given parameters."""
    dut.n.value = n
    dut.p_mask.value = p_mask
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def collect_sequence(dut, n):
    """Collect full sequence from module."""
    sequence = []
    expected_len = 1 << n
    
    for i in range(expected_len + 10):  # Extra cycles for safety
        await RisingEdge(dut.clk)
        
        if is_value_defined(dut.output_valid.value) and int(dut.output_valid.value) == 1:
            val = int(dut.output_value.value)
            sequence.append(val)
            
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    return sequence

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_color_code_generator(dut):
    """Main test for color code generator."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, p_mask, description, should_be_possible)
    # p_mask bit 0 = distance 1, bit 1 = distance 2, etc.
    test_cases = [
        (1, 0b0001, "n=1, P={1} (trivial)", True),
        (2, 0b0001, "n=2, P={1} (Gray code)", True),
        (3, 0b0001, "n=3, P={1} (Gray code)", True),
        (4, 0b0001, "n=4, P={1} (Gray code)", True),
        (4, 0b0110, "n=4, P={2,3} (mixed)", True),
        (3, 0b1000, "n=3, P={4} (likely impossible)", False),
        (4, 0b1000, "n=4, P={4} (negation, impossible)", False),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, p_mask, description, should_be_possible) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  n={n}, p_mask=0b{p_mask:04b}")
        
        try:
            # Start computation
            await start_computation(dut, n, p_mask)
            
            # Collect sequence
            sequence = await collect_sequence(dut, n)
            
            # Check results
            if should_be_possible:
                # Should have produced a valid sequence
                if len(sequence) == 0:
                    raise TestFailure(f"Expected sequence but got none")
                
                if not is_valid_sequence(sequence, n, p_mask):
                    raise TestFailure(f"Invalid sequence: {sequence}")
                
                cocotb.log.info(f"  PASS: Generated valid sequence of {len(sequence)} elements")
                cocotb.log.info(f"  First 5 elements: {sequence[:5] if len(sequence) >= 5 else sequence}")
            else:
                # Should be impossible - no valid output or empty sequence
                if len(sequence) > 0:
                    raise TestFailure(f"Expected impossible but got sequence: {sequence}")
                
                cocotb.log.info(f"  PASS: Correctly identified as impossible")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Results: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info("All tests PASSED!")
