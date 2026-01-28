import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_DIGITS, CLK_NS, MAX_CYCLES = 16, 8, 10, 1000

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

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_change_base(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        (8, 3, [ord(c) for c in '22'], 2, "8 to base 3"),
        (9, 3, [ord(c) for c in '100'], 3, "9 to base 3"),
        (234, 2, [ord(c) for c in '11101010'], 8, "234 to base 2"),
        (16, 2, [ord(c) for c in '10000'], 5, "16 to base 2"),
        (8, 2, [ord(c) for c in '1000'], 4, "8 to base 2"),
        (7, 2, [ord(c) for c in '111'], 3, "7 to base 2"),
        (2, 3, [ord(c) for c in '2'], 1, "2 to base 3"),
    ]
    
    passed = failed = 0
    for i, (x, base, exp_digits, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            dut.x.value = clamp_to_width(x, DATA_WIDTH)
            dut.base.value = clamp_to_width(base, 4)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await Timer(10, units='ns')
            else:
                await Timer(100, units='ns')
            
            result_digits = []
            for i in range(MAX_DIGITS):
                sig = getattr(dut, f'digits_{i}')
                if is_value_defined(sig.value):
                    val = int(sig.value)
                    if val != 0:  # Null char is 0
                        result_digits.append(val)
            
            if len(result_digits) != exp_len:
                raise TestFailure(f"Length mismatch: expected {exp_len}, got {len(result_digits)}. Digits: {result_digits}")
            
            for j in range(exp_len):
                if result_digits[j] != exp_digits[j]:
                    raise TestFailure(f"Digit {j} mismatch: expected {exp_digits[j]}, got {result_digits[j]}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")