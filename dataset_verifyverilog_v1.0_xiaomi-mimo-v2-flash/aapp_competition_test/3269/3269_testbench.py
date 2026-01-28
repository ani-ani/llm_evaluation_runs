import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 10000
MOD = 1000000007

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def compute_expected(A, B):
    total = 0
    for i in range(A, B):
        for j in range(i + 1, B + 1):
            dist = 0
            for k in range(4):  # 4 digits
                i_digit = (i // (10 ** k)) % 10
                j_digit = (j // (10 ** k)) % 10
                dist += abs(i_digit - j_digit)
            total = (total + dist) % MOD
    return total

def int_to_digits(n, length=4):
    digits = [0] * length
    for i in range(length):
        digits[i] = n % 10
        n //= 10
    return digits[::-1]  # Most significant first

async def write_digits(dut, name, digits):
    for i, d in enumerate(digits):
        getattr(dut, f'{name}{i}').value = clamp_to_width(d, 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_distance_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (1, 5, 40, "1 to 5"),
        (288, 291, 76, "288 to 291"),
        (1000, 1002, 18, "1000 to 1002 scaled"),  # Scaled down example
    ]
    
    passed = failed = 0
    
    for A, B, expected, desc in test_cases:
        cocotb.log.info(f"Test {desc}: A={A}, B={B}")
        
        # Scale B to fit 0-9999 if needed
        if B > 9999:
            B = 9999
            A = min(A, B)
            expected = compute_expected(A, B)
            cocotb.log.info(f"  Scaled to A={A}, B={B}, expected={expected}")
        
        try:
            # Write A digits
            digits_A = int_to_digits(A)
            for i, d in enumerate(digits_A):
                getattr(dut, f'A{i}').value = clamp_to_width(d, 4)
            
            # Write B digits
            digits_B = int_to_digits(B)
            for i, d in enumerate(digits_B):
                getattr(dut, f'B{i}').value = clamp_to_width(d, 4)
            
            # Set len (4 for all cases)
            if has_signal(dut, 'len'):
                dut.len.value = 4
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")