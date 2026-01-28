import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
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

async def set_input(dut, bin_str):
    # bin_str like '10000', strip newline
    s = bin_str.strip()
    n = len(s)
    val = 0
    for i, c in enumerate(s):
        if c == '1': val |= (1 << (n - 1 - i))
    # Assuming n_bin is 100-bit vector (MSB first)
    dut.n_bin.value = clamp_to_width(val, 100)

async def get_output(dut):
    # res_bits is 100-bit vector, packed 2-bit per pos (0: '0', 1: '+', 2: '-')
    # Need to unpack to string
    bits = int(dut.res_bits.value)
    result = []
    # Assume pos 99 is MSB (bit 0 in string)
    for i in range(100):
        idx = 99 - i  # MSB first
        chunk = (bits >> (idx * 2)) & 3
        if chunk == 0:
            result.append('0')
        elif chunk == 1:
            result.append('+')
        elif chunk == 2:
            result.append('-')
    # Strip leading zeros
    s = ''.join(result)
    while s and s[0] == '0': s = s[1:]
    return s

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_signed_binary(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("10000", "+0000"),
        ("1111", "+000-"),
        ("10111", "++00-")
    ]
    
    for bin_in, exp in test_cases:
        cocotb.log.info(f"Test: {bin_in}")
        await set_input(dut, bin_in)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        got = await get_output(dut)
        if got != exp:
            raise TestFailure(f"Expected '{exp}', got '{got}'")
        cocotb.log.info(f"PASS: {bin_in} -> {got}")
