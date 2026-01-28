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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_str(s):
    vals = []
    for i in range(8):
        if i < len(s):
            vals.append(ord(s[i]))
        else:
            vals.append(0)
    return vals

async def write_str(dut, s):
    vals = pack_str(s)
    for i in range(8):
        dut.str[i].value = vals[i]

async def read_str(dut):
    result = []
    for i in range(8):
        v = int(dut.result[i].value)
        if v != 0:
            result.append(chr(v))
    return ''.join(result)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reverse_words(dut):
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("python program", "program python"),
        ("java language", "language java"),
        ("indian man", "man indian"),
        ("a b c d", "d c b a"),
        ("hello", "hello")
    ]
    
    for i, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{inp}' -> '{exp}'")
        try:
            await write_str(dut, inp)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            result = await read_str(dut)
            if result != exp:
                raise TestFailure(f"Expected '{exp}', got '{result}'")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
    
    cocotb.log.info("All tests passed")