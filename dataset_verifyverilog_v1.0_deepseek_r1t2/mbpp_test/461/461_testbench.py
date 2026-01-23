import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_upper_ctr(dut):
    """Test upper_ctr module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string, expected_count, description)
    test_cases = [
        ('PYthon', 1, "Test 1: Mixed case with 1 uppercase"),
        ('BigData', 1, "Test 2: BigData - 1 uppercase"),
        ('program', 0, "Test 3: All lowercase - 0 uppercase"),
        ('HELLO', 5, "Additional: All uppercase"),
        ('hello', 0, "Additional: All lowercase"),
        ('AaBbCc', 3, "Additional: Alternating case"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_string, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{test_string}' (length={len(test_string)})")
        
        try:
            # Write string length
            dut.str_len.value = len(test_string)
            
            # Reset for next computation
            await reset_dut(dut)
            
            # Feed characters one by one
            for idx, char in enumerate(test_string):
                # Write character
                dut.char_in.value = ord(char)
                
                # Start computation for this character
                await start_computation(dut)
                
                # Wait for done
                await wait_for_done(dut)
                
                # Small delay to let state settle
                await Timer(10, units='ns')
            
            # Read final result
            if not is_value_defined(dut.count.value):
                raise TestFailure(f"Count is undefined (X/Z)")
            
            result = int(dut.count.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: count = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait before next test
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
