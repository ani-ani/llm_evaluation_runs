import cocotb
from cocotb.triggers import Timer, RisingEdge
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'load_en'): dut.load_en.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_almost_palindrome_counter(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Helper to load string into buffer
    async def load_string(s, length):
        for i, char in enumerate(s):
            dut.addr.value = i
            dut.char_in.value = ord(char)
            dut.load_en.value = 1
            await RisingEdge(dut.clk)
        dut.load_en.value = 0
        # Set window length
        dut.len.value = length

    # Test Case 1: "beginning", window 1-5 (indices 0-4: 'b','e','g','i','n')
    # Expected: 5 (all single chars are palindromes)
    dut.log.info("Test Case 1: 'beginning' [1:5]")
    await load_string("beginning", 5)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 5:
        raise TestFailure(f"Expected 5, got {result}")

    # Test Case 2: "velvet", window 1-6 (full string)
    # Expected: 7
    dut.log.info("Test Case 2: 'velvet' [1:6]")
    await reset_dut(dut)
    await load_string("velvet", 6)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 7:
        raise TestFailure(f"Expected 7, got {result}")

    # Test Case 3: "aaaa", window 1-4
    # All substrings are palindromes. Count = 4+3+2+1 = 10
    dut.log.info("Test Case 3: 'aaaa' [1:4]")
    await reset_dut(dut)
    await load_string("aaaa", 4)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != 10:
        raise TestFailure(f"Expected 10, got {result}")
