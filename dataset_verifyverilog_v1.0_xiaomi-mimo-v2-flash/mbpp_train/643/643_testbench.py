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
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, text):
    # Convert to ASCII bytes, pad to 16 chars with nulls (0)
    padded = (text + '\x00' * 16)[:16]
    chars = [ord(c) for c in padded]
    for i in range(16):
        # Individual assignment for each character
        dut.char_data[i].value = clamp_to_width(chars[i], 8)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_text_match_wordz_middle(dut):
    if not has_signal(dut, 'clk'):
        cocotb.log.error("No clock signal found")
        return
    
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("pythonzabc.", 11, True, "z in middle at index 6"),
        ("zxyabc.", 7, False, "z at start index 0"),
        ("  lang  .", 9, False, "no z"),
        ("az", 2, False, "len 2, no middle"),
        ("azb", 3, True, "z at index 1, len 3"),
        ("abz", 3, False, "z at end index 2"),
        ("azzza", 5, True, "z at index 2"),
        ("zzzzzzzz", 8, True, "z in middle indices 1-6"),
        ("", 0, False, "empty string"),
        ("z", 1, False, "single char z"),
        ("aaaaaaaaaaaaaaaaz", 17, False, "z at index 16 (out of range, treated as len 16)"),
        ("zzzzzzzzzzzzzzzz", 16, False, "all z, len 16, last char is z (index 15)"),
        ("azzzzzzzzzzzzzzz", 16, True, "z at index 1, len 16"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, length, expected, desc) in enumerate(test_cases):
        try:
            cocotb.log.info(f"Test {i+1}: {desc} (text='{text}')")
            
            # Write inputs
            await write_string(dut, text)
            dut.len.value = clamp_to_width(length, 4)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = bool(int(dut.result.value))
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")