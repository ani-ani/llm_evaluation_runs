import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_digits(d):
    # Pack list of digits into a single integer (each 4 bits)
    res = 0
    for i, digit in enumerate(d):
        res |= (digit & 0xF) << (i*4)
    return res

def subtract_one(digits):
    # Subtract 1 from a list of digits (MSB first)
    # Returns new list and borrow flag
    d = digits[:]
    i = len(d) - 1
    while i >= 0 and d[i] == 0:
        d[i] = 9
        i -= 1
    if i >= 0:
        d[i] -= 1
    # Remove leading zeros (but keep at least one digit if all zeros? We assume L>=1)
    while len(d) > 1 and d[0] == 0:
        d.pop(0)
    if not d:
        d = [0]
    return d

def count_numbers(digits, max_len=16):
    # Python reference implementation (digit DP)
    # digits: list of ints (MSB first)
    n = len(digits)
    if n > max_len:
        n = max_len
    digits = digits[-max_len:]  # Take last max_len digits
    # Pad with leading zeros if shorter
    while len(digits) < max_len:
        digits.insert(0, 0)
    
    MOD = 10**9 + 7
    # dp[pos][tight][lead][diff_offset]
    # diff_offset = diff + 8 (to handle -8..8, but max diff is 16, so use 16 offset)
    # For 16 digits, diff range -16 to 16. Use offset 16, size 33.
    OFFSET = 16
    WIDTH = 33
    dp = [[[[0] * WIDTH for _ in range(2)] for _ in range(2)] for _ in range(max_len + 1)]
    dp[0][1][1][OFFSET] = 1  # pos=0, tight=1, lead=1, diff=0
    
    for pos in range(max_len):
        bound = digits[pos]
        for tight in range(2):
            for lead in range(2):
                for diff in range(-16, 17):
                    idx = diff + OFFSET
                    if dp[pos][tight][lead][idx] == 0:
                        continue
                    current = dp[pos][tight][lead][idx]
                    # Max digit to try
                    max_d = bound if tight else 9
                    for d in range(max_d + 1):
                        # Skip digit 4
                        if d == 4:
                            continue
                        new_tight = tight and (d == bound)
                        new_lead = lead and (d == 0)
                        new_diff = diff
                        if not new_lead:
                            if d == 6 or d == 8:
                                new_diff = diff + 1
                            else:
                                new_diff = diff - 1
                        # Clamp diff
                        if new_diff < -16 or new_diff > 16:
                            continue
                        new_idx = new_diff + OFFSET
                        dp[pos + 1][new_tight][new_lead][new_idx] = (dp[pos + 1][new_tight][new_lead][new_idx] + current) % MOD
    
    # Sum valid states at the end: diff must be 0
    res = 0
    for tight in range(2):
        # lead can be 0 or 1? If lead=1 at end, number is 0. But our numbers start from 1, so 0 is not counted unless L=0.
        # We count numbers >= 1, so lead=1 (all zeros) should be excluded. But 0 is not in range [1, ...], so okay.
        # However, if the number is exactly 0, it might be valid? Problem says house numbers >= 1.
        # So we only count lead=0 (non-zero number) or if the number is 0, but we skip.
        for lead in range(1):  # Only lead=0, because lead=1 means number is 0
            idx = 0 + OFFSET
            res = (res + dp[max_len][tight][lead][idx]) % MOD
    return res

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_house_count(dut):
    # Parameters
    MAX_DIGITS = 16
    DATA_WIDTH = 4  # 4 bits per digit (0-9)
    CLK_NS = 10
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (L_str, R_str, expected)
    test_cases = [
        ("30", "70", 11),
        ("66", "69", 2),
        ("100", "999", 0),
        ("1", "10", 2),  # Valid: 1? No 6/8. 1 has 0 lucky, 1 other -> diff -1. 8 has 1 lucky, 0 other -> diff +1. Only 6? 6 has 1 lucky, 0 other -> diff +1. None have diff 0. Wait, example 1: 30-70 has 11. Let's check: 60, 61, 62, 63, 65, 66, 67, 68, 69, 80, 81? No 4. 60: 1 lucky (6), 1 other (0) -> diff 0? 1 lucky, 1 other -> equal? Yes. 66: 2 lucky, 0 other -> not equal. 68: 2 lucky, 0 other. 80: 1 lucky (8), 1 other (0) -> equal. So 60, 62, 63, 65, 67, 69, 80, 82, 83, 85, 87? Wait 60-70. 60, 62, 63, 65, 67, 69 (6 nums). 80 not in range. 30-70 includes 60-70. Also 30-59? 38? 3 lucky? No. 33? 0 lucky, 2 other -> diff -2. So only 60s. But output is 11. Let's list: 60, 62, 63, 65, 67, 69 (6). 70? 7,0 -> 0 lucky, 2 other -> diff -2. 38? 3,8 -> 1 lucky, 1 other -> equal! But 38 is in 30-70. Yes! 38, 48 (no 4), 58. Also 60s. 38, 58, 60, 62, 63, 65, 67, 69. That's 8. Missing 3. 80s? No. 88? No. 68? 2 lucky. 48 no. 36? 3,6 -> 1 lucky, 1 other. 36 is in 30-70. 36, 38, 56, 58, 60, 62, 63, 65, 67, 69. That's 10. 1 missing. 50s? 56, 58. 30s? 36, 38. 60s: 60, 62, 63, 65, 67, 69. 70s? 70 no. 72? 7,2 -> 0 lucky, 2 other. 78? 1 lucky, 1 other -> 78 is in 30-70. Yes! So 36, 38, 56, 58, 60, 62, 63, 65, 67, 69, 78. That's 11. Correct.
        ("66", "69", 2), # 66 (2 lucky), 67 (1 lucky, 1 other), 68 (2 lucky), 69 (1 lucky, 1 other). So 67, 69.
        ("100", "999", 0) # 3 digit numbers. Need equal lucky and non-lucky. Total 3 digits. Equal means 1.5? Impossible. So 0.
    ]
    
    passed = 0
    failed = 0
    
    for i, (L_str, R_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: L={L_str}, R={R_str}")
        
        # Convert strings to digit lists
        L_digits = [int(c) for c in L_str]
        R_digits = [int(c) for c in R_str]
        
        # Compute L-1
        L_minus_1_digits = subtract_one(L_digits)
        
        # Python reference
        count_R = count_numbers(R_digits, MAX_DIGITS)
        count_L = count_numbers(L_minus_1_digits, MAX_DIGITS)
        expected_calc = (count_R - count_L) % (10**9 + 7)
        
        # For the testbench, we verify against the provided expected value
        # But we use the Python ref to generate the correct expected if not provided.
        # In this case, the examples are provided, so we use them.
        
        # Load inputs into DUT (assuming it has inputs for R and L_minus_1)
        # Since the module is designed to compute count(N) for a given N, we run twice.
        # We assume the DUT has inputs: digits, len, and computes count.
        # We will compute for R and L-1 separately and subtract.
        
        # Reset DUT for R computation
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs for R
        # We need to set the digits array. Assuming dut.digits is an array of 4-bit signals.
        # We'll set the length and digits.
        if has_signal(dut, 'len'):
            dut.len.value = len(R_digits) if len(R_digits) <= MAX_DIGITS else MAX_DIGITS
        
        # Fill digits
        for j in range(MAX_DIGITS):
            if has_signal(dut, f'digits_{j}'):
                if j < len(R_digits):
                    getattr(dut, f'digits_{j}').value = R_digits[-(MAX_DIGITS - j)] if len(R_digits) > MAX_DIGITS else R_digits[len(R_digits)-1-j] if j < len(R_digits) else 0
                else:
                    getattr(dut, f'digits_{j}').value = 0
            elif has_signal(dut, 'digits'):
                # It's an array
                if j < len(R_digits):
                    dut.digits[j].value = R_digits[len(R_digits)-1-j]  # Assuming LSB is index 0
                else:
                    dut.digits[j].value = 0
        
        # Special handling for unpacked arrays (common in synthesis)
        # Let's assume digits_0 is LSB (ones place). So we fill from 0 upwards.
        # For R=70, digits = [7, 0]. MSB 7 at index 1, LSB 0 at index 0.
        # So we map R_digits[0] to index len-1.
        # But we have MAX_DIGITS. Let's map R_digits to the high bits of the array.
        # Actually, it's easier to map index i of array to digit at position i.
        # Let's say array index 0 is MSB (10^15), index 15 is LSB (10^0).
        # For 16 digits max.
        
        # Fill for R
        for j in range(MAX_DIGITS):
            val = 0
            # If R_digits length is L, and we have MAX_DIGITS positions.
            # We want to right-align the number (LSB at highest index).
            # If array index 0 is MSB (10^15) and index 15 is LSB (10^0):
            # We want R_digits[0] at index (15 - (len-1)).
            # Actually, let's assume index 0 is 10^0 (LSB). This is standard.
            # So for number 70 (digits [7,0]): index 0 -> 0, index 1 -> 7.
            if j < len(R_digits):
                val = R_digits[len(R_digits) - 1 - j]
            if has_signal(dut, f'digits_{j}'):
                getattr(dut, f'digits_{j}').value = val
            elif has_signal(dut, 'digits'):
                dut.digits[j].value = val
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(5000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"Test {i+1} timeout for R")
            failed += 1
            continue
        
        count_R_hdl = int(dut.result.value)
        
        # Compute for L-1
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Fill digits for L-1
        for j in range(MAX_DIGITS):
            val = 0
            if j < len(L_minus_1_digits):
                val = L_minus_1_digits[len(L_minus_1_digits) - 1 - j]
            if has_signal(dut, f'digits_{j}'):
                getattr(dut, f'digits_{j}').value = val
            elif has_signal(dut, 'digits'):
                dut.digits[j].value = val
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(5000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"Test {i+1} timeout for L-1")
            failed += 1
            continue
        
        count_L_hdl = int(dut.result.value)
        
        result = (count_R_hdl - count_L_hdl) % (10**9 + 7)
        
        # Check against expected
        # Note: The provided expected in examples matches the subtraction.
        if result != expected:
            cocotb.log.error(f"Test {i+1} FAIL: Expected {expected}, got {result} (R: {count_R_hdl}, L: {count_L_hdl})")
            failed += 1
        else:
            cocotb.log.info(f"Test {i+1} PASS")
            passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
