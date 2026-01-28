import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4          # Each digit is 4 bits (0-9)
MAX_DIGITS = 4          # Maximum number of digits
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
MAX_ITER = 1000

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_digits(dut, digits, len):
    """Write digits to DUT."""
    dut.len.value = len
    for i in range(MAX_DIGITS):
        if i < len:
            dut.digits[i].value = digits[i]
        else:
            dut.digits[i].value = 0

async def read_result(dut):
    """Read result digits and count from DUT."""
    count = int(dut.count.value)
    res1 = []
    res2 = []
    for i in range(MAX_DIGITS):
        if is_value_defined(dut.res1[i].value):
            res1.append(int(dut.res1[i].value))
        else:
            res1.append(0)
        if is_value_defined(dut.res2[i].value):
            res2.append(int(dut.res2[i].value))
        else:
            res2.append(0)
    return count, res1, res2

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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# REFERENCE FUNCTIONS (for testbench verification)
# ============================================================================

def int_to_digits(num, length):
    """Convert integer to list of digits (most significant first)."""
    if num == 0:
        return [0] * length
    digits = []
    while num > 0:
        digits.append(num % 10)
        num //= 10
    digits.reverse()
    # Pad to length
    if len(digits) < length:
        digits = [0] * (length - len(digits)) + digits
    return digits

def digits_to_int(digits):
    """Convert list of digits to integer."""
    val = 0
    for d in digits:
        val = val * 10 + d
    return val

def is_handsome(digits):
    """Check if digits form a handsome number."""
    if len(digits) == 0:
        return False
    if len(digits) == 1:
        return True
    for i in range(len(digits)-1):
        if (digits[i] % 2) == (digits[i+1] % 2):
            return False
    return True

def find_prev_handsome(digits, max_iter=MAX_ITER):
    """Find the largest handsome number less than the given number."""
    num = digits_to_int(digits)
    for i in range(1, max_iter+1):
        candidate = num - i
        if candidate < 0:
            break
        cand_digits = int_to_digits(candidate, len(digits))  # might have fewer digits
        cand_digits = [d for d in cand_digits if d != 0 or len(cand_digits)==1]  # strip leading zeros
        if is_handsome(cand_digits):
            return cand_digits
    # If not found, try shorter length
    for length in range(len(digits)-1, 0, -1):
        # Find largest handsome number of that length
        cand = find_largest_handsome(length)
        if cand is not None:
            return cand
    return None

def find_next_handsome(digits, max_iter=MAX_ITER):
    """Find the smallest handsome number greater than the given number."""
    num = digits_to_int(digits)
    for i in range(1, max_iter+1):
        candidate = num + i
        cand_digits = int_to_digits(candidate, len(digits)+1)  # allow one more digit
        # Remove leading zeros if any (should not happen)
        cand_digits = [d for d in cand_digits if d != 0 or len(cand_digits)==1]
        if is_handsome(cand_digits):
            return cand_digits
    # If not found, try longer length
    for length in range(len(digits)+1, len(digits)+2):
        cand = find_smallest_handsome(length)
        if cand is not None:
            return cand
    return None

def find_smallest_handsome(length):
    """Return smallest handsome number of given length."""
    if length == 1:
        return [1]
    digits = []
    # Start with 1 (odd), then even, odd, ...
    for i in range(length):
        if i % 2 == 0:
            digits.append(1)  # odd
        else:
            digits.append(0)  # even
    return digits

def find_largest_handsome(length):
    """Return largest handsome number of given length."""
    if length == 1:
        return [9]
    digits = []
    # Start with 9 (odd), then 8 (even), 9, 8, ...
    for i in range(length):
        if i % 2 == 0:
            digits.append(9)  # odd
        else:
            digits.append(8)  # even
    return digits

def find_closest_handsome(digits):
    """Find the closest handsome number(s) to given digits."""
    prev = find_prev_handsome(digits)
    next = find_next_handsome(digits)
    num = digits_to_int(digits)
    if prev is None and next is None:
        return []
    if prev is None:
        return [next]
    if next is None:
        return [prev]
    dist_prev = num - digits_to_int(prev)
    dist_next = digits_to_int(next) - num
    if dist_prev < dist_next:
        return [prev]
    elif dist_next < dist_prev:
        return [next]
    else:
        return [prev, next]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_handsome_finder(dut):
    """Test the handsome_finder module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (digits, len, description)
    test_cases = [
        ([1, 3], 2, "13 -> 12 14"),
        ([1, 0, 0, 0], 4, "1000 -> 1010"),
        ([2, 2, 0], 3, "220 -> 218? Actually closest is 218 (prev) and 230 (next), dist 2 vs 10 -> 218 only"),
        ([5, 8, 0, 1, 0, 0, 1], 7, "5801001 -> 5810101 (but we limit to 4 digits, so skip)"),
    ]
    
    # Filter test cases to max 4 digits
    test_cases = [tc for tc in test_cases if tc[1] <= MAX_DIGITS]
    
    passed = 0
    failed = 0
    
    for digits, length, description in test_cases:
        dut._log.info(f"Testing: {description}")
        
        # Write inputs
        await write_digits(dut, digits, length)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=5000)
        
        # Read results
        count, res1, res2 = await read_result(dut)
        
        # Trim result digits to actual length (remove leading zeros)
        def trim_digits(d):
            # Find first non-zero digit, but keep at least one digit
            for i in range(len(d)):
                if d[i] != 0:
                    return d[i:]
            return [0]
        
        res1_trim = trim_digits(res1)
        res2_trim = trim_digits(res2)
        
        # Compute expected
        expected = find_closest_handsome(digits[:length])
        
        # Convert expected list of digit lists to compare
        expected_count = len(expected)
        
        # Check count
        if count != expected_count:
            dut._log.error(f"  FAIL: Expected count {expected_count}, got {count}")
            failed += 1
            continue
        
        # Check each result
        success = True
        for i, exp_digits in enumerate(expected):
            if i == 0:
                res = res1_trim
            else:
                res = res2_trim
            if res != exp_digits:
                dut._log.error(f"  FAIL: Result {i+1} mismatch. Expected {exp_digits}, got {res}")
                success = False
                break
        
        if success:
            dut._log.info(f"  PASS")
            passed += 1
        else:
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
