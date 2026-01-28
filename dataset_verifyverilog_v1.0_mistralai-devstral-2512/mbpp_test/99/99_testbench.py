import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 256

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def int_to_packed_str(n, expected_len):
    """Convert int n to packed binary string (MSB-first)"""
    if n == 0:
        return 0, 1
    bin_str = bin(n).replace('0b', '')
    if len(bin_str) > 16:
        raise ValueError(f"Binary string too long: {len(bin_str)}")
    packed = 0
    for i, ch in enumerate(bin_str):
        packed |= (ord(ch) & 0xFF) << (8 * (15 - i))
    return packed, len(bin_str)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_decimal_to_binary(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (8, "1000", "8 -> 1000"),
        (18, "10010", "18 -> 10010"),
        (7, "111", "7 -> 111"),
        (0, "0", "0 -> 0"),
        (15, "1111", "15 -> 1111"),
        (16, "10000", "16 -> 10000"),
    ]
    passed = failed = 0
    
    for i, (inp, exp_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            dut.n.value = clamp_to_width(inp, DATA_WIDTH)
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            if not is_value_defined(dut.len.value):
                raise TestFailure("Length undefined")
            
            packed = int(dut.result.value)
            length = int(dut.len.value)
            
            # Unpack result
            result_str = ""
            for i in range(16):
                char = (packed >> (8 * (15 - i))) & 0xFF
                if char == 0:
                    break
                result_str += chr(char)
            
            if result_str != exp_str:
                raise TestFailure(f"Expected '{exp_str}', got '{result_str}'")
            if length != len(exp_str):
                raise TestFailure(f"Length mismatch: expected {len(exp_str)}, got {length}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")
    cocotb.log.info(f"All {passed} tests passed")
