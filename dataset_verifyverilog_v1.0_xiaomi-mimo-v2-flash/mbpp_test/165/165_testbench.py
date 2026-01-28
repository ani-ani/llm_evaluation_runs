import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=100):
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

async def string_to_signal(dut, s):
    """Pack string into 128-bit signal (16 bytes)"""
    val = 0
    for i, ch in enumerate(s[:16]):
        val |= (ord(ch) << (8 * i))
    dut.string_input.value = val
    dut.string_len.value = len(s)

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_char_position_counter(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ("xbcefg", 2, "positions: b(1), e(4)"),
        ("ABcED", 3, "positions: A(0), B(1), D(4)"),
        ("AbgdeF", 5, "positions: A(0), b(1), g(5), d(3), e(4)"),
        ("A", 1, "single char at pos 0"),
        ("Z", 0, "Z at pos 0, expected pos 25"),
        ("B", 0, "B at pos 0, expected pos 1"),
        ("", 0, "empty string")
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - '{input_str}'")
        
        try:
            # Write string to inputs
            await string_to_signal(dut, input_str)
            
            # Start processing
            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=50)
            else:
                await Timer(100, units='ns')
            
            # Read result
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
        raise TestFailure(f"{failed}/{passed+failed} tests failed")
