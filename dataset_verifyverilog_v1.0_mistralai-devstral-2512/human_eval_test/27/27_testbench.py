import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def feed_string(dut, s, clk_ns=10):
    """Feed string character by character"""
    chars = list(s[:8])  # Max 8 chars
    dut.char_valid.value = 1
    for i, ch in enumerate(chars):
        dut.char_in.value = ord(ch)
        dut.char_index.value = i
        await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    # Wait a few cycles for output
    await Timer(10, units='ns')

async def read_string(dut, max_len=8):
    """Read output characters"""
    chars = []
    cycles = 0
    while cycles < 30:  # Max expected cycles
        await RisingEdge(dut.clk)
        cycles += 1
        if is_value_defined(dut.char_out_valid.value) and int(dut.char_out_valid.value)==1:
            if is_value_defined(dut.char_out.value):
                chars.append(int(dut.char_out.value))
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            break
    return ''.join(chr(c) for c in chars if 0 <= c <= 127)

def flip_case_py(s):
    """Python reference implementation"""
    result = []
    for ch in s:
        if 'A' <= ch <= 'Z':
            result.append(chr(ord(ch) + 32))
        elif 'a' <= ch <= 'z':
            result.append(chr(ord(ch) - 32))
        else:
            result.append(ch)
    return ''.join(result)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_flip_case(dut):
    # Setup clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        ("", "", "empty string"),
        ("Hello", "hELLO", "mixed case"),
        ("Hi!", "hI!", "with punctuation"),
        ("AaBbCc", "aAbBcC", "alternating"),
        ("123", "123", "numbers only"),
        ("Hello!", "hELLO!", "test case 1"),
        ("THESE VIOLENT DELIGHTS HAVE VIOLENT ENDS", "these violent delights have violent ends", "test case 2")
    ]
    
    passed = failed = 0
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Feed input
            await feed_string(dut, inp, CLK_NS)
            
            # Wait for output
            output = await read_string(dut)
            
            # Verify
            if not output:
                raise TestFailure("No output characters received")
            
            # Trim to input length (ignore trailing garbage)
            output = output[:len(inp)]
            
            if output != exp:
                raise TestFailure(f"Expected '{exp}', got '{output}'")
            
            passed += 1
            cocotb.log.info(f"  PASS: '{inp}' -> '{output}'")
            
            # Reset for next test
            if has_signal(dut, 'rst_n'):
                await reset_dut(dut)
            else:
                await Timer(10, units='ns')
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")