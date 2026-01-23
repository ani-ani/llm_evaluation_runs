import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
WORD_COUNT_MAX = 3
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
async def test_longest_word_length(dut):
    """Test the longest_word_length module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (word_lengths, word_count, expected_max, description)
    test_cases = [
        ([7, 3, 7], 3, 7, "python(7), PHP(3), bigdata(7) - max 7"),
        ([1, 2, 3], 3, 3, "a(1), ab(2), abc(3) - max 3"),
        ([5, 3, 5], 3, 5, "small(5), big(3), tall(5) - max 5"),
        ([10, 5], 2, 10, "Two words: 10 and 5 - max 10"),
        ([8], 1, 8, "Single word: 8 - max 8"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (word_lengths, word_count, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs - individual port assignment
            dut.str_len_0.value = clamp_to_width(word_lengths[0], DATA_WIDTH)
            dut.str_len_1.value = clamp_to_width(word_lengths[1] if len(word_lengths) > 1 else 0, DATA_WIDTH)
            dut.str_len_2.value = clamp_to_width(word_lengths[2] if len(word_lengths) > 2 else 0, DATA_WIDTH)
            dut.word_count.value = word_count
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_length.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.max_length.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: max_length = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait for next cycle
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_word_length_edge_cases(dut):
    """Test edge cases for longest_word_length module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Edge cases
    edge_cases = [
        ([255, 0, 0], 1, 255, "Maximum possible length"),
        ([100, 200, 150], 3, 200, "All large values"),
        ([0, 0, 0], 3, 0, "All zero lengths"),
        ([5, 5, 5], 3, 5, "All equal lengths"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (word_lengths, word_count, expected, description) in enumerate(edge_cases):
        cocotb.log.info(f"Edge test {i+1}: {description}")
        
        try:
            # Write inputs
            dut.str_len_0.value = clamp_to_width(word_lengths[0], DATA_WIDTH)
            dut.str_len_1.value = clamp_to_width(word_lengths[1] if len(word_lengths) > 1 else 0, DATA_WIDTH)
            dut.str_len_2.value = clamp_to_width(word_lengths[2] if len(word_lengths) > 2 else 0, DATA_WIDTH)
            dut.word_count.value = word_count
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_length.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.max_length.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: max_length = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait for next cycle
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
