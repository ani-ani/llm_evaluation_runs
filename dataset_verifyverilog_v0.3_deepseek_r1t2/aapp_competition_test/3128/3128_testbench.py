import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 5
MAX_MOVIES = 16
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_star_wars_ordering(dut):
    """Test the star_wars_ordering module."""
    
    # Check required signals
    required_signals = ['clk', 'rst_n', 'start', 'q_type', 'x', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test sequences
    test_cases = [
        # Sample 1: Original Star Wars 6 movies
        [
            (1, 1, None),  # Insert movie 1 at plot position 1
            (1, 2, None),  # Insert movie 2 at plot position 2
            (1, 3, None),  # Insert movie 3 at plot position 3
            (1, 1, None),  # Insert movie 4 at plot position 1 (before existing)
            (1, 2, None),  # Insert movie 5 at plot position 2
            (1, 3, None),  # Insert movie 6 at plot position 3
            (2, 1, 4),     # Query plot 1 -> should be creation 4
            (2, 2, 5),     # Query plot 2 -> should be creation 5
            (2, 3, 6),     # Query plot 3 -> should be creation 6
            (2, 4, 1),     # Query plot 4 -> should be creation 1
            (2, 5, 2),     # Query plot 5 -> should be creation 2
            (2, 6, 3),     # Query plot 6 -> should be creation 3
        ],
        # Sample 2: Simple sequence
        [
            (1, 1, None),
            (1, 2, None),
            (1, 3, None),
            (2, 1, 1),
            (2, 2, 2),
            (2, 3, 3),
        ],
        # Additional test: Insert at beginning multiple times
        [
            (1, 1, None),  # Movie 1 at plot 1
            (1, 1, None),  # Movie 2 at plot 1 (shifts 1->2)
            (1, 3, None),  # Movie 3 at plot 3 (after existing)
            (1, 2, None),  # Movie 4 at plot 2 (between 1 and 3)
            (2, 1, 2),     # Plot 1: movie 2
            (2, 2, 4),     # Plot 2: movie 4
            (2, 3, 1),     # Plot 3: movie 1
            (2, 4, 3),     # Plot 4: movie 3
        ],
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_idx, test_sequence in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Running Test Sequence {test_idx + 1}")
        dut._log.info(f"{'='*60}")
        
        # Reset for each test sequence
        await reset_dut(dut)
        
        for op_idx, (q_type, x, expected) in enumerate(test_sequence):
            # Set inputs
            dut.q_type.value = q_type
            dut.x.value = x
            
            # Pulse start
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Small delay for result to stabilize
            await Timer(10, units='ns')
            
            # Check result for queries
            if q_type == 2:
                if not is_value_defined(dut.result.value):
                    dut._log.error(f"  Query {op_idx+1}: Result is undefined (X/Z)")
                    total_failed += 1
                    continue
                
                result_val = int(dut.result.value)
                if result_val != expected:
                    dut._log.error(f"  Query {op_idx+1}: Plot index {x} -> Expected creation {expected}, got {result_val}")
                    total_failed += 1
                else:
                    dut._log.info(f"  Query {op_idx+1}: Plot index {x} -> Creation {result_val} [PASS]")
                    total_passed += 1
            else:
                dut._log.info(f"  Insert {op_idx+1}: Created movie at plot index {x}")
                total_passed += 1
        
        # Wait one cycle between test sequences
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"FINAL RESULTS: {total_passed}/{total_passed + total_failed} operations passed")
    dut._log.info(f"{'='*60}")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} operations failed")
    
    dut._log.info("ALL TESTS PASSED!")