import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 1          # Each bracket is 1 bit
MAX_N = 16              # Maximum sequence length
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

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bracket_fixer(dut):
    """Test bracket fixer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (sequence, expected_result, description)
    # expected_result: 1 for Yes, 0 for No
    test_cases = [
        (")(", 1, "Example 1: )( -> Yes"),
        ("(()", 0, "Example 2: (() -> No"),
        ("()", 1, "Example 3: () -> Yes"),
        (")))))(((((", 0, "Example 4: )))))(((((( -> No"),
        (")", 0, "Single closing bracket"),
        ("(", 0, "Single opening bracket"),
        ("", 1, "Empty sequence"),
        ("()()", 1, "Two pairs"),
        ("())(", 0, "Imbalance in middle"),
        ("((()))", 1, "Nested correct"),
        (")))((", 0, "Too many closing first"),
        ("(()))(", 0, "Almost correct but extra close"),
        ("()(())", 1, "Complex correct"),
        ("((())", 0, "Missing closing"),
        ("())", 0, "Extra closing"),
        ("(()(", 0, "Extra opening"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (seq_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Convert string to 16-bit vector and get length
        n = len(seq_str)
        if n > MAX_N:
            cocotb.log.warning(f"Sequence too long ({n} > {MAX_N}), truncating")
            seq_str = seq_str[:MAX_N]
            n = MAX_N
        
        # Convert to bit vector: 0 for '(', 1 for ')'
        vec = 0
        for idx, char in enumerate(seq_str):
            if char == ')':
                vec |= (1 << idx)
        
        # Set inputs
        dut.seq.value = vec
        dut.valid_length.value = n
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
