import cocotb
from cocotb.triggers import Timer, RisingEdge
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

CLK_PERIOD_NS = 10
R = 4
C = 4

# ============================================================================
# HELPER: Compute expected result
# ============================================================================

def compute_expected(K):
    """Compute expected grey count for given K in 4x4 grid."""
    sequence = []
    # Generate zig-zag sequence
    for d in range(R + C - 1):
        cells = []
        for r in range(R):
            c = d - r
            if 0 <= c < C:
                cells.append((r, c))
        if d % 2 == 1:  # odd diagonal, reverse
            cells = cells[::-1]
        sequence.extend(cells)
    
    # Count grey cells up to K
    grey_count = 0
    for i, (r, c) in enumerate(sequence):
        if (r & c) == 0:
            grey_count += 1
        if i == K - 1:
            return grey_count
    return grey_count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_zigzag_grey_counter(dut):
    """Test zigzag grey counter with K=1,2,4,6,8,10,12,16."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: K values from 1 to 16 (full range for 4x4)
    test_cases = [1, 2, 4, 6, 8, 10, 12, 16]
    
    passed = 0
    failed = 0
    
    for k in test_cases:
        expected = compute_expected(k)
        
        # Set K value
        dut.K.value = k
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done = False
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            dut._log.error(f"K={k}: Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"K={k}: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            dut._log.error(f"K={k}: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"K={k}: result={result} [PASS]")
            passed += 1
        
        # Wait for idle
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")