import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION - Match HDL parameters
# ============================================================================
MAX_FRAGMENTS = 8
MAX_FRAGMENT_LENGTH = 16
OVERLAP_THRESHOLD = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
RESULT_MAX_LENGTH = 128

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.fragment_valid.value = 0
    dut.fragment_end.value = 0
    dut.loading_done.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_fragments(dut, fragments):
    """Load fragments into the DUT."""
    for fragment in fragments:
        for char in fragment:
            dut.fragment_data.value = ord(char)
            dut.fragment_valid.value = 1
            await RisingEdge(dut.clk)
        dut.fragment_valid.value = 0
        dut.fragment_end.value = 1
        await RisingEdge(dut.clk)
        dut.fragment_end.value = 0
    dut.loading_done.value = 1
    await RisingEdge(dut.clk)
    dut.loading_done.value = 0

async def wait_for_result(dut):
    """Wait for result or ambiguous flag."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.ambiguous.value) and int(dut.ambiguous.value) == 1:
            return None  # Ambiguous
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            break
    else:
        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
    
    # Read result string
    result = []
    while True:
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            result.append(chr(int(dut.result_char.value)))
        if is_value_defined(dut.result_done.value) and int(dut.result_done.value) == 1:
            break
        await RisingEdge(dut.clk)
    return ''.join(result)

# ============================================================================
# TEST CASES (Scaled down to 4 fragments max)
# ============================================================================

TEST_CASES = [
    {
        "name": "Sample 1 scaled",
        "fragments": [
            "The quick brown fox",
            "brown fox jumps over",
            "fox jumps over the lazy",
            "over the lazy dog"
        ],
        "expected": "The quick brown fox jumps over the lazy dog",
        "ambiguous": False
    },
    {
        "name": "Sample 2",
        "fragments": [
            "cdefghi",
            "efghijk",
            "efghijx",
            "abcdefg"
        ],
        "expected": None,
        "ambiguous": True
    },
    {
        "name": "Sample 3",
        "fragments": [
            "cdefghix",
            "efghijk",
            "abcdefghi",
            "cdefghij"
        ],
        "expected": "abcdefghijk",
        "ambiguous": False
    },
    {
        "name": "Simple chain",
        "fragments": [
            "abcdefg",
            "defghij",
            "ghijklm"
        ],
        "expected": "abcdefghijklm",
        "ambiguous": False
    },
    {
        "name": "Ambiguous overlap",
        "fragments": [
            "abcde",
            "cdefg",
            "efghi"
        ],
        "expected": None,
        "ambiguous": True
    }
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_manuscript_reconstructor(dut):
    """Test manuscript reconstruction module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Run test cases
    passed = 0
    failed = 0
    
    for test_case in TEST_CASES:
        dut._log.info(f"\nTesting: {test_case['name']}")
        
        # Reset for each test case
        await reset_dut(dut)
        
        # Load fragments
        fragments = test_case['fragments'][:MAX_FRAGMENTS]  # Clamp to max
        dut._log.info(f"Loading {len(fragments)} fragments")
        await load_fragments(dut, fragments)
        
        # Wait for result
        result = await wait_for_result(dut)
        
        # Check result
        if test_case['ambiguous']:
            if result is not None:
                dut._log.error(f"Expected ambiguous, got: {result}")
                failed += 1
            else:
                dut._log.info("PASS: Correctly identified as ambiguous")
                passed += 1
        else:
            if result is None:
                dut._log.error("Expected result, but got ambiguous")
                failed += 1
            elif result == test_case['expected']:
                dut._log.info(f"PASS: Result matches: {result}")
                passed += 1
            else:
                dut._log.error(f"FAIL: Expected '{test_case['expected']}', got '{result}'")
                failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
