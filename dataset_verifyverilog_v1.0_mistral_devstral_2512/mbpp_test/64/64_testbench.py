import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16        # Score width
NAME_WIDTH = 8         # Name/ID width
NUM_ELEMENTS = 4       # Number of tuples
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

def encode_name(name_str):
    """Encode a name string to integer using ASCII values."""
    # Convert string to integer by packing ASCII bytes
    result = 0
    for i, c in enumerate(name_str[:4]):  # Max 4 chars for 8-bit width
        result |= ord(c) << (i * 8)
    return result

def decode_name(name_int):
    """Decode integer back to string (4 chars max)."""
    chars = []
    for i in range(4):
        char = (name_int >> (i * 8)) & 0xFF
        if char != 0:
            chars.append(chr(char))
    return ''.join(chars)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sort_tuples_by_score(dut):
    """Test sorting of tuples based on second value (score)."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (input_tuples, expected_tuples, description)
    # Each tuple: (name_str, score)
    test_cases = [
        (
            [('English', 88), ('Science', 90), ('Maths', 97), ('Social', 82)],
            [('Social', 82), ('English', 88), ('Science', 90), ('Maths', 97)],
            "Test 1: Mix of scores"
        ),
        (
            [('Telugu', 49), ('Hindhi', 54), ('Social', 33), ('Math', 70)],
            [('Social', 33), ('Telugu', 49), ('Hindhi', 54), ('Math', 70)],
            "Test 2: Lower scores"
        ),
        (
            [('Physics', 96), ('Chemistry', 97), ('Biology', 45), ('Science', 88)],
            [('Biology', 45), ('Science', 88), ('Physics', 96), ('Chemistry', 97)],
            "Test 3: High scores"
        ),
        (
            [('A', 50), ('B', 50), ('C', 50), ('D', 50)],
            [('A', 50), ('B', 50), ('C', 50), ('D', 50)],
            "Test 4: Equal scores"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_tuples, expected_tuples, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        cocotb.log.info(f"{'='*60}")
        
        try:
            # Write input data (unpack tuples)
            for i, (name_str, score) in enumerate(input_tuples):
                name_int = encode_name(name_str)
                score_val = clamp_to_width(score, DATA_WIDTH)
                
                # Write to DUT ports
                getattr(dut, f'in_name_{i}').value = name_int
                getattr(dut, f'in_score_{i}').value = score_val
                
                cocotb.log.info(f"  Input [{i}]: {name_str:>8} = {score_val}")
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read and verify output
            output_tuples = []
            for i in range(NUM_ELEMENTS):
                if is_value_defined(getattr(dut, f'out_name_{i}').value) and \
                   is_value_defined(getattr(dut, f'out_score_{i}').value):
                    
                    name_int = int(getattr(dut, f'out_name_{i}').value)
                    score_val = int(getattr(dut, f'out_score_{i}').value)
                    name_str = decode_name(name_int)
                    output_tuples.append((name_str, score_val))
                else:
                    raise TestFailure(f"Output [{i}] is undefined (X/Z)")
            
            # Log output
            for i, (name_str, score) in enumerate(output_tuples):
                cocotb.log.info(f"  Output[{i}]: {name_str:>8} = {score}")
            
            # Verify against expected
            if output_tuples != expected_tuples:
                raise TestFailure(
                    f"Mismatch!\n"
                    f"Expected: {expected_tuples}\n"
                    f"Got:      {output_tuples}"
                )
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"RESULTS: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
