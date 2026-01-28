import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ASCII values for pattern matching
CHAR_S = 0x73
CHAR_T = 0x74
CHAR_D = 0x64

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'char_in'):
        dut.char_in.value = 0
    if has_signal(dut, 'str_len'):
        dut.str_len.value = 0
    
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
async def test_string_pattern_matcher(dut):
    """Test the string pattern matcher for 'std' occurrences."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (string, expected_count, description)
    test_cases = [
        ("letstdlenstdporstd", 3, "Three 'std' occurrences"),
        ("truststdsolensporsd", 1, "Single 'std' at position 5"),
        ("makestdsostdworthit", 2, "Two 'std' occurrences"),
        ("stds", 1, "Pattern at start"),
        ("", 0, "Empty string"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_string, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{test_string}' (len={len(test_string)})")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Set string length
            str_len = len(test_string)
            dut.str_len.value = str_len
            
            # Start computation
            await start_computation(dut)
            
            # Feed characters one by one
            for idx, char in enumerate(test_string):
                dut.char_in.value = ord(char)
                await RisingEdge(dut.clk)
                
                # Wait for shift operations (2 cycles per character after first)
                # For first character: just load, for others: load + shift
                if idx == 0:
                    await RisingEdge(dut.clk)
                else:
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
            
            # Send extra cycles to flush window and complete
            for _ in range(4):
                dut.char_in.value = 0
                await RisingEdge(dut.clk)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.count.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
