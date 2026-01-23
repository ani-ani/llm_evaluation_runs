import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
N = 8          # Max card types
K = 4          # Max envelope types
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000  # Allow more cycles for DP computation

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

async def write_card_data(dut, card_types):
    """Write card data to the DUT.
    card_types: list of (w, h, q) tuples
    """
    # Clear all first
    for i in range(N):
        if has_signal(dut, f'card_width_{i}'):
            getattr(dut, f'card_width_{i}').value = 0
            getattr(dut, f'card_height_{i}').value = 0
            getattr(dut, f'card_qty_{i}').value = 0
        else:
            dut.card_width[i].value = 0
            dut.card_height[i].value = 0
            dut.card_qty[i].value = 0
    
    # Write actual data
    for i, (w, h, q) in enumerate(card_types):
        if i >= N:
            break
        w_clamped = clamp_to_width(w, DATA_WIDTH)
        h_clamped = clamp_to_width(h, DATA_WIDTH)
        q_clamped = clamp_to_width(q, DATA_WIDTH)
        
        if has_signal(dut, f'card_width_{i}'):
            getattr(dut, f'card_width_{i}').value = w_clamped
            getattr(dut, f'card_height_{i}').value = h_clamped
            getattr(dut, f'card_qty_{i}').value = q_clamped
        else:
            dut.card_width[i].value = w_clamped
            dut.card_height[i].value = h_clamped
            dut.card_qty[i].value = q_clamped

async def reset_dut(dut):
    """Reset the DUT."""
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_envelope_optimizer(dut):
    """Main test function for envelope optimizer."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            "name": "Sample 1: k=1",
            "cards": [(10, 10, 5), (9, 8, 10), (4, 12, 20), (12, 4, 8), (2, 3, 16)],
            "k": 1,
            "expected": 5836
        },
        {
            "name": "Sample 2: k=2",
            "cards": [(10, 10, 5), (9, 8, 10), (4, 12, 20), (12, 4, 8), (2, 3, 16)],
            "k": 2,
            "expected": 1828
        },
        {
            "name": "Sample 3: k=5",
            "cards": [(10, 10, 5), (9, 8, 10), (4, 12, 20), (12, 4, 8), (2, 3, 16)],
            "k": 5,
            "expected": 0
        },
        {
            "name": "Simple case: 2 cards, k=1",
            "cards": [(5, 5, 1), (3, 3, 2)],
            "k": 1,
            "expected": 2  # envelope 5x5, waste = 1*(25-25) + 2*(25-9) = 0 + 2*16 = 32? Wait recalc
        },
    ]
    
    # Fix the simple case calculation
    # Cards: (5,5,1) and (3,3,2)
    # Envelope must be 5x5 (since 5>3)
    # Waste: 1*(25-25) + 2*(25-9) = 0 + 2*16 = 32
    test_cases[3]["expected"] = 32
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test: {tc['name']}")
        cocotb.log.info(f"Cards: {tc['cards']}")
        cocotb.log.info(f"k = {tc['k']}")
        cocotb.log.info(f"Expected: {tc['expected']}")
        
        try:
            # Write card data
            await write_card_data(dut, tc['cards'])
            
            # Write k value
            if has_signal(dut, 'num_env_types'):
                dut.num_env_types.value = tc['k']
            elif has_signal(dut, 'k'):
                dut.k.value = tc['k']
            else:
                cocotb.log.warning("Cannot find num_env_types or k signal")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                cocotb.log.info(f"Result: {result}")
                
                if result == tc['expected']:
                    cocotb.log.info(f"PASS")
                    passed += 1
                else:
                    cocotb.log.error(f"FAIL: Expected {tc['expected']}, got {result}")
                    failed += 1
            else:
                raise TestFailure("Result is undefined (X/Z)")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")