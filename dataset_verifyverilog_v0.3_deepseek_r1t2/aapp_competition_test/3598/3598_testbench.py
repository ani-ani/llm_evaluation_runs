import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4          # 4 bits per digit (0-9)
MAX_MAGNETS = 4
MAX_DIGITS_PER_MAG = 3
MAX_TOTAL_DIGITS = MAX_MAGNETS * MAX_DIGITS_PER_MAG
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000      # enough for state machine

# ============================================================================
# HELPER: Convert string to packed magnet data and length
# ============================================================================

def string_to_magnet(s):
    """Convert a string of digits to packed data (12 bits) and length (2 bits)."""
    # Remove any non-digit characters
    digits = [int(ch) for ch in s if ch.isdigit()]
    if len(digits) > MAX_DIGITS_PER_MAG:
        raise ValueError(f"Magnet string too long: {s}")
    # Pack: LSB first (first digit in lower bits)
    packed = 0
    for i, d in enumerate(digits):
        packed |= (d & 0xF) << (i * DATA_WIDTH)
    return packed, len(digits)

# ============================================================================
# HELPER: Flip a magnet (simulates Verilog flip logic)
# ============================================================================

def flip_magnet(packed, length):
    """Return flipped packed data and length, or None if invalid."""
    if length == 0:
        return None
    digits = []
    for i in range(length):
        d = (packed >> (i * DATA_WIDTH)) & 0xF
        digits.append(d)
    # Check flippable
    for d in digits:
        if d not in [0,1,6,8,9]:
            return None
    # Reverse and flip
    flipped = []
    for d in reversed(digits):
        if d == 6:
            flipped.append(9)
        elif d == 9:
            flipped.append(6)
        else:
            flipped.append(d)
    # Pack
    packed_flipped = 0
    for i, d in enumerate(flipped):
        packed_flipped |= (d & 0xF) << (i * DATA_WIDTH)
    return packed_flipped, len(flipped)

# ============================================================================
# HELPER: Compare two strings (packed, length) for sorting
# ============================================================================

def compare_strings(packedA, lenA, packedB, lenB):
    """Return True if A should come before B (A+B <= B+A)."""
    # Build concatenated arrays
    def get_digit(packed, length, idx):
        if idx < length:
            return (packed >> (idx * DATA_WIDTH)) & 0xF
        return 0
    total = lenA + lenB
    concatA = []
    for i in range(total):
        if i < lenA:
            concatA.append(get_digit(packedA, lenA, i))
        else:
            concatA.append(get_digit(packedB, lenB, i - lenA))
    concatB = []
    for i in range(total):
        if i < lenB:
            concatB.append(get_digit(packedB, lenB, i))
        else:
            concatB.append(get_digit(packedA, lenA, i - lenB))
    # Lexicographic compare
    for a, b in zip(concatA, concatB):
        if a < b:
            return True
        elif a > b:
            return False
    return True  # equal

# ============================================================================
# HELPER: Concatenate sorted magnets into a string
# ============================================================================

def concatenate_sorted(magnets):
    """magnets: list of (packed, length) in sorted order."""
    digits = []
    for packed, length in magnets:
        for i in range(length):
            d = (packed >> (i * DATA_WIDTH)) & 0xF
            digits.append(str(d))
    return ''.join(digits)

# ============================================================================
# HELPER: Expected result for a given test case
# ============================================================================

def expected_result(magnet_strings):
    """Compute expected cheapest price for given list of magnet strings."""
    # Preprocess each magnet: original and flipped (if valid)
    magnets = []
    for s in magnet_strings:
        packed, length = string_to_magnet(s)
        orig = (packed, length)
        flip = flip_magnet(packed, length)
        magnets.append((orig, flip))
    # Brute‑force all combinations
    best = None
    n = len(magnets)
    for mask in range(1 << n):
        selected = []
        for i in range(n):
            use_flip = (mask >> i) & 1
            orig, flip = magnets[i]
            if use_flip and flip is not None:
                selected.append(flip)
            else:
                selected.append(orig)
        # Sort selected using compare_strings
        # Bubble sort
        sorted_list = selected[:]
        for pass_num in range(2):  # two passes sufficient for 4 items
            for i in range(n-1):
                if not compare_strings(sorted_list[i][0], sorted_list[i][1],
                                       sorted_list[i+1][0], sorted_list[i+1][1]):
                    sorted_list[i], sorted_list[i+1] = sorted_list[i+1], sorted_list[i]
        # Concatenate
        candidate = concatenate_sorted(sorted_list)
        # Compare with best (lexicographic)
        if best is None or candidate < best:
            best = candidate
    return best

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cheapest_price(dut):
    """Test the cheapest_price module with sample inputs."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational – just wait a bit for propagation
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (["110", "6"], "0116"),
        (["7", "72"], "727")   # Note: '7' and '72' contain non‑flippable digits; our module will keep originals only
    ]
    
    for i, (magnet_strings, expected) in enumerate(test_cases):
        dut._log.info(f"Running test {i+1}: magnets {magnet_strings}")
        
        # Prepare magnet data for DUT (pad to MAX_MAGNETS=4, unused magnets length=0)
        packed_list = []
        len_list = []
        for s in magnet_strings:
            packed, length = string_to_magnet(s)
            packed_list.append(packed)
            len_list.append(length)
        # Pad to 4 magnets
        while len(packed_list) < MAX_MAGNETS:
            packed_list.append(0)
            len_list.append(0)
        
        # Write to DUT
        for idx in range(MAX_MAGNETS):
            # Access mag_data[idx] and mag_len[idx]
            dut.mag_data[idx].value = packed_list[idx]
            dut.mag_len[idx].value = len_list[idx]
        
        if is_sequential:
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for result_valid
            cycles = 0
            while not (is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1):
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure(f"Timeout waiting for result_valid")
            
            # Read result
            result_len = int(dut.result_len.value)
            result_digits = []
            for j in range(result_len):
                if is_value_defined(dut.result_digits[j].value):
                    result_digits.append(str(int(dut.result_digits[j].value)))
                else:
                    result_digits.append('0')
            result_str = ''.join(result_digits)
        else:
            # Combinational – just read after a delay
            await Timer(500, units='ns')
            result_len = int(dut.result_len.value)
            result_digits = []
            for j in range(result_len):
                if is_value_defined(dut.result_digits[j].value):
                    result_digits.append(str(int(dut.result_digits[j].value)))
                else:
                    result_digits.append('0')
            result_str = ''.join(result_digits)
        
        if result_str != expected:
            raise TestFailure(f"Test {i+1}: expected '{expected}', got '{result_str}'")
        
        dut._log.info(f"Test {i+1} passed: {result_str}")
    
    dut._log.info("All tests passed!")

# ============================================================================
# OPTIONAL: TEST FOR SINGLE‑DIGIT MAGNETS (simpler)
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_single_digit(dut):
    """Test with single‑digit magnets (simpler)."""
    # Similar to above but with single‑digit strings
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test: digits [9,6,0,1] -> after flipping 9→6, we get [6,6,0,1] sorted -> "0166"
    magnets = ["9", "6", "0", "1"]
    expected = "0166"
    
    packed_list = []
    len_list = []
    for s in magnets:
        packed, length = string_to_magnet(s)
        packed_list.append(packed)
        len_list.append(length)
    while len(packed_list) < MAX_MAGNETS:
        packed_list.append(0)
        len_list.append(0)
    
    for idx in range(MAX_MAGNETS):
        dut.mag_data[idx].value = packed_list[idx]
        dut.mag_len[idx].value = len_list[idx]
    
    if is_sequential:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        cycles = 0
        while not (is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure("Timeout")
        result_len = int(dut.result_len.value)
        result_digits = [str(int(dut.result_digits[j].value)) for j in range(result_len)]
        result_str = ''.join(result_digits)
    else:
        await Timer(500, units='ns')
        result_len = int(dut.result_len.value)
        result_digits = [str(int(dut.result_digits[j].value)) for j in range(result_len)]
        result_str = ''.join(result_digits)
    
    if result_str != expected:
        raise TestFailure(f"Single‑digit test failed: expected '{expected}', got '{result_str}'")
    dut._log.info(f"Single‑digit test passed: {result_str}")
