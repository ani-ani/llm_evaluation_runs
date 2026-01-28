import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_decimal_digits(num, length):
    """Convert integer to list of decimal digits (MSB first), padded to length."""
    if num == 0:
        digits = [0]
    else:
        digits = [int(d) for d in str(num)]
    if len(digits) < length:
        digits = [0] * (length - len(digits)) + digits
    elif len(digits) > length:
        digits = digits[-length:]
    return digits

def power_of_2_str(e):
    val = 1 << e
    return str(val)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_digit_dp_matcher(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        (1000000, 1),    # Should output 468559
        (1000000, 5),    # Should output 49401
        (1000000, 16),   # Should output 20
        (9000000000000000000, 62), # Should output 1
    ]

    # Constants based on Verilog spec
    MAX_DIGITS = 19
    DIGIT_WIDTH = 4
    PATTERN_WIDTH = 4

    for n_val, e_val in test_cases:
        # Prepare data
        n_str = str(n_val)
        n_digits = to_decimal_digits(n_val, MAX_DIGITS)
        n_len = len(n_str) if n_val > 0 else 1
        
        p_str = power_of_2_str(e_val)
        p_digits = to_decimal_digits(int(p_str), MAX_DIGITS)
        p_len = len(p_str)

        cocotb.log.info(f"Testing N={n_val}, E={e_val}, Pattern={p_str}")

        # Write inputs
        # n_digits: 19 packed 4-bit values. We assign to individual indices or packed array.
        # Assuming Verilog: reg [3:0] n_digits [0:18];
        if has_signal(dut, 'n_digits'):
            for i in range(MAX_DIGITS):
                dut.n_digits[i].value = n_digits[i]
        elif has_signal(dut, 'n_digits_0'): # Individual ports
            for i in range(MAX_DIGITS):
                getattr(dut, f'n_digits_{i}').value = n_digits[i]
        
        if has_signal(dut, 'n_len'):
            dut.n_len.value = n_len

        if has_signal(dut, 'pattern_digits'):
            for i in range(MAX_DIGITS):
                dut.pattern_digits[i].value = p_digits[i]
        
        if has_signal(dut, 'p_len'):
            dut.p_len.value = p_len

        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        max_cycles = 10000
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout for N={n_val}, E={e_val}")

        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for N={n_val}, E={e_val}")
            
        result = int(dut.result.value)
        
        # Calculate expected output manually for verification
        # Note: Python counting might be slow for 9e18, but we rely on the provided example outputs
        # or calculate only if N is small.
        if n_val <= 1000000:
            expected = count_python(n_val, e_val)
        else:
            # For large N, use the hardcoded expected value from problem description
            if n_val == 9000000000000000000 and e_val == 62:
                expected = 1
            else:
                # Calculate using Python logic for the test case if needed (omitted for brevity)
                continue

        if result != expected:
            raise TestFailure(f"Mismatch: N={n_val}, E={e_val}. Expected {expected}, got {result}")
        
        cocotb.log.info(f"Pass: Result={result}")

def count_python(n, e):
    # Helper to count in Python for verification of small N
    target = str(1 << e)
    count = 0
    for k in range(n + 1):
        if target in str(k):
            count += 1
    return count
