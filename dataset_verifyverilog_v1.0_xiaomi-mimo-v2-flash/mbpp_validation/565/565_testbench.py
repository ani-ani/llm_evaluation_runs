import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 20

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_string(s, max_len=16):
    s = s.ljust(max_len, '\0')
    packed = 0
    for i, c in enumerate(s[:max_len]):
        packed |= (ord(c) & 0xFF) << (i * 8)
    return packed

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_split_string(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("python", [ord(c) for c in 'python']),
        ("Name", [ord(c) for c in 'Name']),
        ("program", [ord(c) for c in 'program'])
    ]
    
    for i, (inp_str, expected_chars) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{inp_str}'")
        
        packed = pack_string(inp_str)
        length = len(expected_chars)
        
        dut.start.value = 1
        dut.char_in.value = packed
        dut.length.value = length
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        received = []
        for j in range(length):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                raise TestFailure(f"Valid not high at cycle {j}")
            received.append(int(dut.char_out.value))
        
        await wait_for_done(dut)
        
        if received != expected_chars:
            raise TestFailure(f"Expected {expected_chars}, got {received}")
