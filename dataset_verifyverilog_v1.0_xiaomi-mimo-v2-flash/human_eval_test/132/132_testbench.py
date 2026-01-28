import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
STRING_MAX = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'char_done'): dut.char_done.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def feed_string(dut, test_str):
    """Feed characters one by one, respecting ready signal"""
    for char in test_str:
        dut.char_data.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        # Wait until ready (or just proceed, assuming combinational ready)
        if has_signal(dut, 'ready'):
            while not int(dut.ready.value):
                await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    dut.char_done.value = 1
    await RisingEdge(dut.clk)
    dut.char_done.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_nested(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (string, expected_result)
    # Expected: 0=invalid, 1=valid_no_nesting, 2=valid_with_nesting
    test_cases = [
        ('[[]]', 2),          # True: has nesting
        (']]]]]]][[[[[]', 0), # False: invalid
        ('[][]', 1),          # False: valid but no nesting
        ('[]', 1),            # False: valid but no nesting
        ('[[[[]]]]', 2),      # True: has nesting
        (']]]]]]]]]]', 0),   # False: invalid
        ('[][][[]]', 2),      # True: has nesting
        ('[[]', 0),           # False: invalid
        ('[]]', 0),           # False: invalid
        ('[[]][[', 2),        # True: valid with nesting
        ('[[][]]', 2),        # True: valid with nesting
        ('', 0),              # False: empty
        ('[[[[[[[[', 0),      # False: invalid (unbalanced)
        (']]]]]]]]]', 0),     # False: invalid
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{test_str}' -> expected {expected}")
        try:
            if is_seq:
                await reset_dut(dut)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await feed_string(dut, test_str)
                await wait_for_done(dut)
            else:
                # Combinational version
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Brief pause between tests
        if is_seq:
            await Timer(10, units='ns')
    
    cocotb.log.info(f"Total: passed={passed}, failed={failed}")
    if failed:
        raise TestFailure(f"{failed} tests failed")