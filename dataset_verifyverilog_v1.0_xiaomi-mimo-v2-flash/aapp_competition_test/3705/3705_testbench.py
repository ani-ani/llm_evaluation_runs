import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_N = 100
CLK_NS = 10
MAX_CYCLES = 200

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def count_eights(n, digits_str):
    count = 0
    for i in range(min(n, len(digits_str))):
        if digits_str[i] == '8':
            count += 1
    return count

def compute_expected(n, digits_str):
    if n < 11:
        return 0
    eight_count = count_eights(n, digits_str)
    max_phones = n // 11
    return min(eight_count, max_phones)

async def write_digit_string(dut, digits_str, n):
    # digits_str is a string of length n containing '0'-'9'
    # We need to convert each character to an 8-bit ASCII value
    # but since our design likely expects 8-bit per character
    # we'll write each char as ASCII value
    
    # For simplicity, assume the interface accepts digits_in as 100 bits
    # where bits[8*i+7:8*i] = ASCII of char i
    
    if has_signal(dut, 'digits_in'):
        # Create 800-bit value (100 chars * 8 bits)
        # But we need to assign to the actual port width
        port_width = len(str(dut.digits_in)) if hasattr(dut.digits_in, '__len__') else 800
        
        # Actually, let's check if it's a bus
        if hasattr(dut.digits_in, '__len__'):
            # It's a vector, write individual elements
            for i in range(min(n, 100)):
                char_val = ord(digits_str[i]) if i < len(digits_str) else ord('0')
                dut.digits_in[i].value = clamp_to_width(char_val, 8)
        else:
            # It's a single port, pack into one value
            packed = 0
            for i in range(min(n, 100)):
                char_val = ord(digits_str[i]) if i < len(digits_str) else ord('0')
                packed |= (char_val & 0xFF) << (i * 8)
            dut.digits_in.value = packed
    
    if has_signal(dut, 'n'):
        dut.n.value = clamp_to_width(n, 7)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_phone_counter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (11, "00000000008", 1, "single 8 at end"),
        (22, "0011223344556677889988", 2, "two 8s"),
        (11, "31415926535", 0, "no 8s"),
        (11, "80000000000", 1, "valid phone number"),
        (10, "8888888888", 0, "n too small"),
        (20, "88888888888888888888", 1, "10 8s but n=20 gives 1"),
        (30, "888888888888888888888888888888", 2, "15 8s, n=30 gives 2"),
        (100, "8"*100, 9, "100 8s gives 9 (100//11=9)"),
        (100, "0"*99 + "8", 1, "only one 8 at end"),
        (100, "0"*90 + "8"*10, 9, "10 8s with n=100"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, digits_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_val}, expected={expected})")
        try:
            # Write inputs
            await write_digit_string(dut, digits_str, n_val)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")