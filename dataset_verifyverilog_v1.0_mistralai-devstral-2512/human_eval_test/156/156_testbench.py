import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 10  # For input num
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Helper to pack bytes into integer (for checking)
def pack_bytes(byte_list):
    result = 0
    for i, b in enumerate(byte_list):
        result |= (b & 0xFF) << (i * 8)
    return result

def int_to_roman_str(num):
    """Python reference for roman numeral generation."""
    if num == 0:
        return ""
    if num > 1000 or num < 1:
        raise ValueError("Number out of range")
    
    # Mapping for digits
    thousands = ["", "m"]
    hundreds = ["", "c", "cc", "ccc", "cd", "d", "dc", "dcc", "dccc", "cm"]
    tens = ["", "x", "xx", "xxx", "xl", "l", "lx", "lxx", "lxxx", "xc"]
    ones = ["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix"]
    
    th = num // 1000
    ho = (num % 1000) // 100
    te = (num % 100) // 10
    on = num % 10
    
    s = thousands[th] + hundreds[ho] + tens[te] + ones[on]
    return s

def str_to_bytes(s):
    """Convert string to list of ASCII bytes."""
    return [ord(c) for c in s]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_int_to_mini_roman(dut):
    """Test the int_to_mini_roman module."""
    # Check if it's a sequential module (has clk/rst)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        from cocotb.clock import Clock
        from cocotb.triggers import RisingEdge
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational, just wait a bit
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (19, "xix"),
        (152, "clii"),
        (251, "ccli"),
        (426, "cdxxvi"),
        (500, "d"),
        (1, "i"),
        (4, "iv"),
        (43, "xliii"),
        (90, "xc"),
        (94, "xciv"),
        (532, "dxxxii"),
        (900, "cm"),
        (994, "cmxciv"),
        (1000, "m"),
    ]
    
    passed = 0
    failed = 0
    
    for num, exp_str in test_cases:
        exp_bytes = str_to_bytes(exp_str)
        exp_len = len(exp_bytes)
        exp_packed = pack_bytes(exp_bytes)
        
        cocotb.log.info(f"Testing {num} -> '{exp_str}' (len={exp_len}, packed={exp_packed})")
        
        try:
            # Set input
            dut.num.value = clamp_to_width(num, DATA_WIDTH)
            
            # For sequential, trigger start
            if is_seq and has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational or need time to settle
                await Timer(10, units='ns')
            
            # Read outputs
            if not (has_signal(dut, 'result') and has_signal(dut, 'len')):
                raise TestFailure("Missing result or len signal")
            
            result_val = safe_int(dut.result.value, 0)
            len_val = safe_int(dut.len.value, 0)
            
            if len_val != exp_len:
                raise TestFailure(f"Length mismatch: expected {exp_len}, got {len_val}")
            
            if result_val != exp_packed:
                # Provide detailed comparison
                got_bytes = []
                for i in range(MAX_LEN):
                    byte = (result_val >> (i * 8)) & 0xFF
                    got_bytes.append(byte)
                got_str = "".join(chr(b) for b in got_bytes if b > 0)
                raise TestFailure(f"Result mismatch: expected '{exp_str}' ({exp_packed}), got '{got_str}' ({result_val})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL [num={num}]: {e}")
            failed += 1
    
    # Edge case: num=0 (if allowed by spec, but spec says 1-1000, so optional)
    # Add if you want to test zero handling
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")

async def wait_for_done(dut, max_cycles=1000):
    from cocotb.triggers import RisingEdge
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done'):
            try:
                if int(dut.done.value) == 1:
                    return True
            except ValueError:
                pass
    raise TestFailure(f"Timeout after {max_cycles} cycles")