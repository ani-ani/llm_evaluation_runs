import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DIGIT_WIDTH = 4
NUM_DIGITS = 4
MOD = 1000000007

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ADDITIONAL HELPER FUNCTIONS FOR THIS TEST
# ============================================================================

def int_to_digits(num, num_digits=NUM_DIGITS):
    """Convert integer to list of digits (MSB first), padded with zeros."""
    digits = []
    for _ in range(num_digits):
        digits.append(num % 10)
        num //= 10
    return digits[::-1]  # Reverse to get MSB first

def python_distance(a_digits, b_digits):
    """Compute distance between two numbers given as digit lists."""
    return sum(abs(ad - bd) for ad, bd in zip(a_digits, b_digits))

async def write_digits(dut, prefix, digits):
    """Write digits to DUT signals, e.g., a0, a1, a2, a3."""
    for i in range(NUM_DIGITS):
        signal_name = f"{prefix}{i}"
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = digits[i]
        else:
            raise TestFailure(f"Signal {signal_name} not found")

# ============================================================================
# MAIN TEST: DISTANCE CALCULATOR
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_distance_calculator(dut):
    """Test the distance calculator module with various pairs."""
    
    # No clock/reset needed for combinational module
    
    # Test cases: (a, b, expected_distance)
    # Note: We use 4-digit representation with leading zeros.
    test_cases = [
        (1, 5, 4),          # 0001 vs 0005: |0-0|+|0-0|+|0-0|+|1-5| = 4
        (1234, 5678, 16),   # |1-5|+|2-6|+|3-7|+|4-8| = 4+4+4+4=16
        (288, 291, 8),      # 0288 vs 0291: |0-0|+|2-2|+|8-9|+|8-1| = 0+0+1+7=8
        (1000, 1000, 0),    # Same number
        (9999, 0, 36),      # 9999 vs 0000: 9*4=36
        (0, 0, 0),          # Edge case
        (5432, 2345, 12),   # |5-2|+|4-3|+|3-4|+|2-5| = 3+1+1+3 = 8? Wait compute: 5-2=3, 4-3=1, 3-4=1, 2-5=3 => 8. Let's recalc: 5432 vs 2345: digits: [5,4,3,2] vs [2,3,4,5] -> |5-2|=3, |4-3|=1, |3-4|=1, |2-5|=3 => total 8. Hmm not 12. Let's pick another: 1234 vs 4321: |1-4|=3, |2-3|=1, |3-2|=1, |4-1|=3 => 8. Actually many pairs give 8. Let's compute a random: 1000 vs 5000: |1-5|=4, rest zeros => 4. So we need to ensure test cases are correct. We'll compute expected in Python.
    ]
    
    # We'll compute expected distances using Python function
    for a, b, _ in test_cases:
        a_digits = int_to_digits(a)
        b_digits = int_to_digits(b)
        expected = python_distance(a_digits, b_digits)
        
        # Write to DUT
        await write_digits(dut, 'a', a_digits)
        await write_digits(dut, 'b', b_digits)
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.dist.value):
            raise TestFailure(f"Result is undefined for a={a}, b={b}")
        
        result = int(dut.dist.value)
        
        if result != expected:
            raise TestFailure(f"Distance mismatch for a={a}, b={b}: expected {expected}, got {result}")
        
        dut._log.info(f"Distance({a}, {b}) = {result} [PASS]")

# ============================================================================
# TOTAL SUM VERIFICATION (COMPUTED IN PYTHON)
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_total_sum_examples(dut):
    """Verify total sum for given examples by computing in Python."""
    
    examples = [
        (1, 5, 40),
        (288, 291, 76),
        (1000000, 10000000, 581093400),
    ]
    
    dut._log.info("Computing total sum for examples using Python...")
    
    for A, B, expected in examples:
        # For the large example, we cannot compute in Python due to scale.
        # Instead, we compute only for the first two examples.
        if A == 1000000:
            dut._log.info(f"Range [{A}, {B}]: expected {expected} (precomputed by problem, not verified in testbench)")
            continue
        
        total = 0
        # Iterate over all numbers in [A, B]
        for i in range(A, B + 1):
            for j in range(A, B + 1):
                a_digits = int_to_digits(i)
                b_digits = int_to_digits(j)
                total += python_distance(a_digits, b_digits)
        total %= MOD
        
        if total != expected:
            raise TestFailure(f"Total sum for [{A}, {B}]: expected {expected}, got {total}")
        else:
            dut._log.info(f"Total sum for [{A}, {B}] = {total} [PASS]")

# ============================================================================
# ADDITIONAL TEST: RANDOM PAIRS
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_random_pairs(dut):
    """Test with random digit pairs to ensure robustness."""
    import random
    
    random.seed(42)
    num_tests = 20
    
    for _ in range(num_tests):
        a_digits = [random.randint(0, 9) for _ in range(NUM_DIGITS)]
        b_digits = [random.randint(0, 9) for _ in range(NUM_DIGITS)]
        
        # Compute expected distance
        expected = python_distance(a_digits, b_digits)
        
        # Write to DUT
        await write_digits(dut, 'a', a_digits)
        await write_digits(dut, 'b', b_digits)
        
        await Timer(10, units='ns')
        
        result = int(dut.dist.value)
        
        if result != expected:
            raise TestFailure(f"Random test failed: expected {expected}, got {result}")
    
    dut._log.info(f"Random pairs test: {num_tests} tests passed")