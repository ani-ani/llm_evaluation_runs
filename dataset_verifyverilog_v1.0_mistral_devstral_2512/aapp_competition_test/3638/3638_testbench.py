import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2          # R=00, P=01, S=10
PATTERN_LENGTH = 8      # Max pattern length (scaled down from 10^5)
NUM_PATTERNS = 4        # Max number of predictions (scaled down from 10)
SCORE_WIDTH = 8         # Max score = 28 for length 8
N_WIDTH = 20            # For n up to 10^6
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Character encoding
CHAR_TO_CODE = {'R': 0, 'P': 1, 'S': 2}
CODE_TO_CHAR = {0: 'R', 1: 'P', 2: 'S'}

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

# ============================================================================
# PATTERN ENCODING/DECODING
# ============================================================================

def encode_pattern(pattern_str):
    """Encode pattern string into packed integer."""
    packed = 0
    for i, char in enumerate(pattern_str):
        code = CHAR_TO_CODE[char]
        packed |= (code << (i * DATA_WIDTH))
    return packed

def decode_pattern(packed_int, length):
    """Decode packed integer back to pattern string."""
    chars = []
    for i in range(length):
        code = (packed_int >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
        chars.append(CODE_TO_CHAR[code])
    return ''.join(chars)

# ============================================================================
# BORDER SCORE COMPUTATION (Python reference)
# ============================================================================

def compute_border_score(pattern):
    """Compute sum of lengths of all proper borders using KMP prefix function."""
    k = len(pattern)
    if k == 0:
        return 0
    
    # Compute KMP prefix function pi
    pi = [0] * k
    for i in range(1, k):
        j = pi[i-1]
        while j > 0 and pattern[i] != pattern[j]:
            j = pi[j-1]
        if pattern[i] == pattern[j]:
            j += 1
        pi[i] = j
    
    # Sum border lengths
    score = 0
    j = pi[k-1]
    while j > 0:
        score += j
        j = pi[j-1]
    
    return score

def sort_patterns(patterns):
    """Sort patterns by border score ascending, stable."""
    scored = [(compute_border_score(p), i, p) for i, p in enumerate(patterns)]
    scored.sort(key=lambda x: (x[0], x[1]))  # Sort by score, then input order
    return [p for _, _, p in scored]

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    
    # Initialize all pattern inputs to 0
    for i in range(NUM_PATTERNS):
        dut.patterns_in[i].value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut, n_val, patterns):
    """Set inputs and start computation."""
    dut.n.value = n_val
    
    # Write patterns individually
    for i, pattern_str in enumerate(patterns):
        packed = encode_pattern(pattern_str)
        dut.patterns_in[i].value = packed
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def read_output_patterns(dut):
    """Read sorted patterns from output."""
    results = []
    for i in range(NUM_PATTERNS):
        if is_value_defined(dut.patterns_out[i].value):
            packed = int(dut.patterns_out[i].value)
            pattern_str = decode_pattern(packed, PATTERN_LENGTH)
            results.append(pattern_str)
        else:
            results.append(None)
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_sorter(dut):
    """Test pattern sorter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, patterns)
    test_cases = [
        (
            3,  # n
            ['PP', 'RR', 'PS', 'SS'],  # patterns
            ['PS', 'PP', 'RR', 'SS']   # expected sorted
        ),
        (
            20,
            ['PRSPS', 'SSSSS', 'PPSPP'],
            ['PRSPS', 'PPSPP', 'SSSSS']
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, patterns, expected) in enumerate(test_cases):
        # Ensure pattern length matches module parameter
        actual_pattern_length = len(patterns[0])
        if actual_pattern_length > PATTERN_LENGTH:
            cocotb.log.warning(f"Test case {i}: pattern length {actual_pattern_length} > {PATTERN_LENGTH}, truncating")
            patterns = [p[:PATTERN_LENGTH] for p in patterns]
            expected = [p[:PATTERN_LENGTH] for p in expected]
        
        # Pad patterns to PATTERN_LENGTH if needed
        for j in range(len(patterns)):
            if len(patterns[j]) < PATTERN_LENGTH:
                patterns[j] = patterns[j] + 'R' * (PATTERN_LENGTH - len(patterns[j]))
                expected[j] = expected[j] + 'R' * (PATTERN_LENGTH - len(expected[j]))
        
        cocotb.log.info(f"Test {i+1}: n={n_val}, patterns={patterns}")
        
        try:
            # Start computation
            await start_computation(dut, n_val, patterns)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output
            output_patterns = await read_output_patterns(dut)
            
            # Verify
            for j in range(NUM_PATTERNS):
                if j < len(expected):
                    if output_patterns[j] != expected[j]:
                        raise TestFailure(
                            f"Position {j}: expected '{expected[j]}', got '{output_patterns[j]}'"
                        )
                else:
                    # Extra positions should be 0 or unchanged
                    if output_patterns[j] is not None and output_patterns[j].strip('R') != '':
                        raise TestFailure(f"Extra position {j} not empty: '{output_patterns[j]}'")
            
            cocotb.log.info(f"  PASS: {output_patterns[:len(expected)]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# TESTBENCH EXECUTION
# ============================================================================

if __name__ == "__main__":
    # This is for standalone testing if needed
    print("Testbench module loaded.")
    print(f"Configuration: PATTERN_LENGTH={PATTERN_LENGTH}, NUM_PATTERNS={NUM_PATTERNS}")
    print("Example scores:")
    for pattern in ['PP', 'PS', 'SSSSS', 'PPSPP', 'PRSPS']:
        if len(pattern) <= PATTERN_LENGTH:
            score = compute_border_score(pattern)
            print(f"  {pattern}: score={score}")
