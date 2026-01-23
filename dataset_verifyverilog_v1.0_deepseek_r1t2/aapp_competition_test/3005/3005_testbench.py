import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8          # Bits per character
STRING_MAX_LEN = 16     # Maximum string length
RESULT_WIDTH = 5        # Bits for result (max 16)
CLK_PERIOD_NS = 10      # Clock period in ns
MAX_CYCLES = 100000     # Maximum cycles for computation (large enough)

# ============================================================================
# HELPER FUNCTIONS (as per guidelines)
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
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_string(dut, test_string):
    """Write string to input array, pad with zeros."""
    n = len(test_string)
    if n > STRING_MAX_LEN:
        n = STRING_MAX_LEN
        test_string = test_string[:STRING_MAX_LEN]
    
    # Write character bytes to string_in array
    for i in range(STRING_MAX_LEN):
        if i < n:
            dut.string_in[i].value = ord(test_string[i])
        else:
            dut.string_in[i].value = 0
    
    # Write length
    dut.length_in.value = n
    return n

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
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
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def maximal_factoring_weight(s):
    """Compute weight of maximal factoring for a string (reference)."""
    n = len(s)
    if n == 0:
        return 0
    dp = [[0]*n for _ in range(n)]
    for i in range(n):
        dp[i][i] = 1
    
    for L in range(2, n+1):
        for i in range(0, n-L+1):
            j = i + L - 1
            min_val = L  # worst case: all characters distinct
            # Check splits
            for k in range(i, j):
                val = dp[i][k] + dp[k+1][j]
                if val < min_val:
                    min_val = val
            # Check repetitions
            for d in range(1, L//2 + 1):
                if L % d == 0:
                    # Check periodicity with period d
                    periodic = True
                    for r in range(d):
                        for p in range(1, L//d):
                            if s[i + r] != s[i + r + p*d]:
                                periodic = False
                                break
                        if not periodic:
                            break
                    if periodic:
                        if dp[i][i+d-1] < min_val:
                            min_val = dp[i][i+d-1]
            dp[i][j] = min_val
    return dp[0][n-1]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_maximal_factoring(dut):
    """Test the MaximalFactoring module with adapted test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases (adapted to max length 16)
    test_cases = [
        ("PRATTATTATTIC", 6, "Original sample 1 (truncated to 16)"),
        ("GGGGGGGGG", 1, "All same character"),
        ("PRIME", 5, "All distinct"),
        ("BABBABABBABBA", 6, "Original sample 4 (truncated to 16)"),
        ("ARPARPARPARPAR", 5, "Additional test (truncated to 16)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}' (len={len(input_str)})")
        cocotb.log.info(f"  Expected weight: {expected}")
        
        try:
            # Write input string and length
            n = await write_string(dut, input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST FOR RANDOM STRINGS (OPTIONAL)
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_random_strings(dut):
    """Test with randomly generated strings."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Generate 5 random strings of length 8
    random.seed(42)
    for _ in range(5):
        length = random.randint(1, 8)
        test_string = ''.join(random.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZ', k=length))
        expected = maximal_factoring_weight(test_string)
        
        cocotb.log.info(f"\nRandom test: '{test_string}' (len={length})")
        cocotb.log.info(f"  Expected weight: {expected}")
        
        try:
            await write_string(dut, test_string)
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            raise
