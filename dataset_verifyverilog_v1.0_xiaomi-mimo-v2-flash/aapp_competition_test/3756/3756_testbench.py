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

def pack_digits(digits):
    """Pack list of int digits into packed integer."""
    res = 0
    for i, d in enumerate(digits):
        res |= (d & 0xF) << (i * 4)
    return res

def unpack_packed(val, length):
    """Unpack packed integer into list of digits."""
    res = []
    for i in range(length):
        res.append((val >> (i * 4)) & 0xF)
    return res

def parse_grade_str(s):
    if '.' in s:
        int_part, frac_part = s.split('.')
    else:
        int_part, frac_part = s, ""
    
    # Convert to lists of ints (LSB first for packing)
    int_digits = [int(c) for c in reversed(int_part)]
    frac_digits = [int(c) for c in frac_part]
    
    return int_digits, frac_digits

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_grade_rounding(dut):
    # Setup clock
    dut.rst_n.value = 1
    dut.start.value = 0
    
    if has_signal(dut, 'clk'):
        clk_period = 10  # ns
        cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    else:
        # Combinational logic assumed
        clk_period = 0

    # Reset
    if has_signal(dut, 'clk'):
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test cases from problem
    test_cases = [
        ("10.245", 1, "10.25"),
        ("10.245", 2, "10.3"),
        ("9.2", 100, "9.2"),
        ("1.555", 10, "2"),  # Carry chain
        ("0.9454", 1, "1"),
        ("99.5", 1, "100"),
        ("5.59", 1, "6"),
    ]

    for i, (grade_str, t_val, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {grade_str} with t={t_val}")
        
        # Parse inputs
        int_digits, frac_digits = parse_grade_str(grade_str)
        n_val = len(int_digits) + 1 + len(frac_digits) # int + dot + frac
        
        # Clamp n to 200
        n_val = min(n_val, 200)
        
        # Pack digits into fixed-width arrays (max 100 digits each)
        MAX_DIGITS = 100
        packed_int = pack_digits(int_digits)
        packed_frac = pack_digits(frac_digits)
        
        # Assign inputs
        if has_signal(dut, 'n'):
            dut.n.value = n_val
        if has_signal(dut, 't'):
            dut.t.value = t_val
        if has_signal(dut, 'grade_int'):
            dut.grade_int.value = packed_int
        if has_signal(dut, 'grade_frac'):
            dut.grade_frac.value = packed_frac
            
        # Trigger start
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        dut.start.value = 0
        
        # Wait for done
        if has_signal(dut, 'done'):
            timeout = 0
            while not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(10, units='ns')
                timeout += 1
                if timeout > 1000:
                    raise TestFailure(f"Timeout waiting for done on test {i+1}")
        else:
            # Combinational, assume result is stable
            await Timer(100, units='ns')

        # Read outputs
        res_int = 0
        res_frac = 0
        res_len = 0
        
        if has_signal(dut, 'result_int'):
            res_int = int(dut.result_int.value)
        if has_signal(dut, 'result_frac'):
            res_frac = int(dut.result_frac.value)
        if has_signal(dut, 'result_len'):
            res_len = int(dut.result_len.value)
        
        # Construct output string
        # Unpack result
        # Determine how many digits to take from int part
        # If result_len includes fraction, we need to be careful.
        # Logic: result_len is total chars (excluding dot).
        # We assume result_int provides up to 101 bits (digits), result_frac provides up to 100.
        
        # Heuristic reconstruction for verification:
        # Find position of decimal point in result
        # If fractional part is all zeros, no dot.
        
        frac_digits_res = unpack_packed(res_frac, MAX_DIGITS)
        int_digits_res = unpack_packed(res_int, MAX_DIGITS)
        
        # Trim trailing zeros in frac (remember LSB is leftmost, so trailing in array means MSB side)
        # frac_digits_res[0] is left of dot.
        # We print up to the last non-zero or originally present digits?
        # The problem says "Do not print trailing zeroes".
        
        # Determine if we have a decimal point
        has_frac = any(d != 0 for d in frac_digits_res)
        
        # Construct string
        out_str = ""
        
        # Integer part: print all digits (MSB to LSB)
        # int_digits_res is LSB first.
        # Find highest non-zero or print 0 if all zero
        int_str = ""
        leading = True
        for d in reversed(int_digits_res):
            if leading and d == 0:
                continue
            leading = False
            int_str += str(d)
        if int_str == "": int_str = "0"
        
        out_str += int_str
        
        if has_frac:
            out_str += "."
            # Fractional part: LSB first (left of dot) to MSB (right)
            # We should not strip trailing zeros in the output if they are significant,
            # but the problem says strip trailing zeroes.
            # Since input guarantees no trailing 0s, and rounding produces trailing 0s only if rounded to integer.
            # If has_frac is true, we print.
            # But we might have '0's in the middle. We should stop at the last non-zero digit OR the defined precision.
            # Given the HDL simulates infinite precision or fixed width, we might have garbage in upper bits if not cleared.
            # However, 'result_frac' is driven by logic. We should just print all digits up to a reasonable limit or strip trailing 0s.
            # Let's print digits up to 100 (MAX_DIGITS) but strip trailing 0s.
            
            # Find last non-zero index
            last_nonzero = -1
            for idx, d in enumerate(frac_digits_res):
                if d != 0:
                    last_nonzero = idx
            
            # If last_nonzero is -1 (all zeros), has_frac should have been false, but just in case
            if last_nonzero == -1:
                pass # Should not happen
            else:
                for idx in range(last_nonzero + 1):
                    out_str += str(frac_digits_res[idx])

        cocotb.log.info(f"  Result: {out_str}")
        
        if out_str != expected_str:
            raise TestFailure(f"Expected '{expected_str}', got '{out_str}'")
