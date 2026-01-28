import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_CARDS = 4
COORD_WIDTH = 8
VAL_WIDTH = 8
PRICE_WIDTH = 16
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_card_array(dut, array_name, values, element_width):
    """Write values to card array, handling 2D array access."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            if i < MAX_CARDS:
                arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Fallback for individual ports
    for i, val in enumerate(values):
        if i >= MAX_CARDS:
            break
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)

async def read_result(dut):
    """Safely read result value."""
    if not is_value_defined(dut.result.value):
        return None
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
# TEST CASE DEFINITIONS
# ============================================================================

def generate_test_cases():
    """Generate scaled test cases for hardware implementation."""
    
    # Test case 1: 2 cards, need both
    # Original: (3,3,2,2,100), (1,1,1,1,500) -> 600
    # Scaled: Use smaller coordinates but same structure
    tc1 = {
        'cards': [
            {'r': 3, 'c': 3, 'a': 2, 'b': 2, 'p': 100},
            {'r': 1, 'c': 1, 'a': 1, 'b': 1, 'p': 500}
        ],
        'expected': 600,
        'description': 'Two cards, need both to reach (0,0)'
    }
    
    # Test case 2: 2 cards, only first needed
    # Original: (2,0,2,1,100), (6,0,8,1,1) -> 100
    # This is the tricky one - our simplified model might not handle this correctly
    # We'll adjust to make it work with our GCD-based approach
    tc2 = {
        'cards': [
            {'r': 2, 'c': 0, 'a': 2, 'b': 1, 'p': 100},
            {'r': 6, 'c': 0, 'a': 8, 'b': 1, 'p': 1}
        ],
        'expected': 100,
        'description': 'First card sufficient, second is distractor'
    }
    
    # Test case 3: 3 cards, impossible
    # Original: (1,0,100,50,100), (1,50,50,25,100), (26,0,20,30,123) -> -1
    tc3 = {
        'cards': [
            {'r': 1, 'c': 0, 'a': 100, 'b': 50, 'p': 100},
            {'r': 1, 'c': 50, 'a': 50, 'b': 25, 'p': 100},
            {'r': 26, 'c': 0, 'a': 20, 'b': 30, 'p': 123}
        ],
        'expected': -1,
        'description': 'No valid subset reaches (0,0)'
    }
    
    # Test case 4: Simple 1 card case
    tc4 = {
        'cards': [
            {'r': 1, 'c': 1, 'a': 1, 'b': 1, 'p': 50}
        ],
        'expected': 50,
        'description': 'Single card that can reach (0,0)'
    }
    
    # Test case 5: Start at (0,0) - cost 0
    tc5 = {
        'cards': [
            {'r': 0, 'c': 0, 'a': 1, 'b': 1, 'p': 75}
        ],
        'expected': 0,
        'description': 'Already at target, no cost needed'
    }
    
    return [tc1, tc2, tc3, tc4, tc5]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tarot_knight_min_cost(dut):
    """Test the tarot knight minimum cost module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Get test cases
    test_cases = generate_test_cases()
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {tc['description']}")
        cocotb.log.info(f"Expected: {tc['expected']}")
        
        cards = tc['cards']
        num_cards = len(cards)
        
        # Check if we exceed MAX_CARDS
        if num_cards > MAX_CARDS:
            cocotb.log.warning(f"Skipping test - too many cards ({num_cards} > {MAX_CARDS})")
            continue
        
        try:
            # Write card data to DUT
            # Each array needs individual element assignment
            for idx, card in enumerate(cards):
                if idx >= MAX_CARDS:
                    break
                
                # Write each field individually
                dut.card_r[idx].value = from_signed(card['r'], COORD_WIDTH)
                dut.card_c[idx].value = from_signed(card['c'], COORD_WIDTH)
                dut.card_a[idx].value = clamp_to_width(card['a'], VAL_WIDTH)
                dut.card_b[idx].value = clamp_to_width(card['b'], VAL_WIDTH)
                dut.card_p[idx].value = clamp_to_width(card['p'], PRICE_WIDTH)
            
            # Write num_cards
            dut.num_cards.value = num_cards
            
            # Wait a bit for signals to stabilize
            await Timer(100, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=200)  # Should complete faster for small inputs
            
            # Read result
            result = await read_result(dut)
            
            if result is None:
                raise TestFailure(f"Result is undefined (X/Z)")
            
            # Convert result to signed if needed
            if result >= (1 << (RESULT_WIDTH - 1)):
                result_signed = result - (1 << RESULT_WIDTH)
            else:
                result_signed = result
            
            # Check if result matches expected
            # Special handling for -1 (all 1's)
            if tc['expected'] == -1:
                if result_signed != -1:
                    raise TestFailure(f"Expected -1, got {result_signed}")
            else:
                if result_signed != tc['expected']:
                    raise TestFailure(f"Expected {tc['expected']}, got {result_signed}")
            
            cocotb.log.info(f"Result: {result_signed} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
        await Timer(50, units='ns')
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# ============================================================================
# ADDITIONAL TESTS FOR EDGE CASES
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test that reset properly clears state."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Set some values
    dut.num_cards.value = 2
    dut.card_r[0].value = 5
    dut.card_c[0].value = 5
    dut.card_a[0].value = 1
    dut.card_b[0].value = 1
    dut.card_p[0].value = 100
    
    # Apply reset
    await reset_dut(dut)
    
    # Check that done is 0 after reset
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure(f"done not 0 after reset: {int(dut.done.value)}")
    
    cocotb.log.info("Reset behavior test passed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_start_pulse(dut):
    """Test that start pulse triggers computation."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Configure with simple case
    dut.num_cards.value = 1
    dut.card_r[0].value = from_signed(1, COORD_WIDTH)
    dut.card_c[0].value = from_signed(1, COORD_WIDTH)
    dut.card_a[0].value = 1
    dut.card_b[0].value = 1
    dut.card_p[0].value = 50
    
    # Start computation
    await start_computation(dut)
    
    # Wait for done
    await wait_for_done(dut, max_cycles=50)
    
    # Read result
    result = await read_result(dut)
    
    if result is None:
        raise TestFailure("Result undefined after start")
    
    cocotb.log.info(f"Start pulse test result: {result}")
