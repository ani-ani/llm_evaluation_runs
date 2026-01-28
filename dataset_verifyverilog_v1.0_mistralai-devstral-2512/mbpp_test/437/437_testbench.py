import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_CHARS = 16
CLK_NS = 10

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

# Convert string to list of ASCII values, padded to MAX_CHARS
def string_to_vals(s, max_len=MAX_CHARS):
    vals = [ord(c) for c in s]
    if len(vals) > max_len:
        vals = vals[:max_len]
    while len(vals) < max_len:
        vals.append(0)
    return vals

# Filter string: keep chars at even positions (1-indexed) -> indices 1,3,5... (0-indexed)
def filter_odd(s):
    result = []
    for i, c in enumerate(s):
        if (i + 1) % 2 == 0:  # i is 0-indexed, i+1 is 1-indexed position
            result.append(c)
    return ''.join(result)

async def write_input_chars(dut, vals, length):
    for i in range(MAX_CHARS):
        if has_signal(dut, f'char_{i}'):
            v = vals[i] if i < length else 0
            dut.__getattr__(f'char_{i}').value = clamp_to_width(v, DATA_WIDTH)
    dut.len.value = clamp_to_width(length, 4)

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_remove_odd(dut):
    # Combinational module
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    dut.rst_n.value = 1
    
    test_cases = [
        ("python", "yhn"),
        ("program", "rga"),
        ("language", "agae"),
        ("", ""),
        ("a", ""),  # Single char, odd position 1, kept
        ("ab", "b"),
        ("abcdef", "bdf"),
        ("1234567890", "24680")
    ]
    
    passed = failed = 0
    
    for idx, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: input='{input_str}' -> expected='{expected_str}'")
        try:
            input_vals = string_to_vals(input_str, MAX_CHARS)
            input_len = len(input_str)
            
            await write_input_chars(dut, input_vals, input_len)
            
            # Wait a bit for combinational logic
            await Timer(10, units='ns')
            
            # Read output
            output_len_val = safe_int(dut.out_len.value)
            output_vals = []
            for i in range(MAX_CHARS):
                if has_signal(dut, f'out_char_{i}'):
                    v = int(getattr(dut, f'out_char_{i}').value)
                    output_vals.append(v)
            
            # Build output string
            output_str = ''
            for i in range(output_len_val):
                if i < len(output_vals):
                    output_str += chr(output_vals[i])
            
            # Validate
            if output_str != expected_str:
                raise TestFailure(f"Mismatch: got='{output_str}'")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
