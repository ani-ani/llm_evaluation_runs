import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500

def encrypt_char(char_ascii):
    """Python reference implementation"""
    if 97 <= char_ascii <= 122:
        val = char_ascii - 97
        shifted = (val + 4) % 26
        return shifted + 97
    return char_ascii

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'char_done'): dut.char_done.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_string(dut, s):
    """Send string character by character"""
    for i, c in enumerate(s):
        dut.char_in.value = ord(c)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)
    # Mark end of string
    dut.char_done.value = 1
    await RisingEdge(dut.clk)
    dut.char_done.value = 0

async def read_encrypted(dut, expected_len):
    """Read encrypted characters from output"""
    result = []
    cycles = 0
    while len(result) < expected_len and cycles < 200:
        await RisingEdge(dut.clk)
        if has_signal(dut, 'char_valid_out') and is_value_defined(dut.char_valid_out.value):
            if int(dut.char_valid_out.value) == 1 and is_value_defined(dut.char_out.value):
                result.append(int(dut.char_out.value))
        cycles += 1
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_encrypt_string(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational only - no clock needed
        pass
    
    test_cases = [
        ('hi', 'lm'),
        ('asdfghjkl', 'ewhjklnop'),
        ('gf', 'kj'),
        ('et', 'ix'),
        ('a', 'e'),
        ('faewfawefaewg', 'jeiajeaijeiak'),
        ('hellomyfriend', 'lippsqcjvmirh'),
        ('dxzdlmnilfuhmilufhlihufnmlimnufhlimnufhfucufh', 'hbdhpqrmpjylqmpyjlpmlyjrqpmqryjlpmqryjljygyjl')
    ]
    
    passed = failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{input_str}' -> '{expected_str}'")
        try:
            # Reset for each test
            if is_seq:
                await reset_dut(dut)
            
            # Send input string
            if is_seq:
                await send_string(dut, input_str)
            else:
                # For combinational: feed one char at a time
                result = []
                for c in input_str:
                    dut.char_in.value = ord(c)
                    await Timer(10, units='ns')
                    if is_value_defined(dut.char_out.value):
                        result.append(int(dut.char_out.value))
                expected = [ord(c) for c in expected_str]
                if result != expected:
                    raise TestFailure(f"Combinational: Expected {expected}, got {result}")
                passed += 1
                continue
            
            # Wait for processing
            if is_seq:
                await wait_for_done(dut, max_cycles=200)
                
                # Read output
                output_chars = await read_encrypted(dut, len(input_str))
                
                # Validate
                expected = [ord(c) for c in expected_str]
                if output_chars != expected:
                    raise TestFailure(f"Expected {expected}, got {output_chars}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_case_single_char(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    input_char = 'a'
    expected_char = 'e'
    
    cocotb.log.info(f"Edge case: '{input_char}' -> '{expected_char}'")
    try:
        if is_seq:
            await send_string(dut, input_char)
            await wait_for_done(dut, max_cycles=100)
            
            output_chars = await read_encrypted(dut, 1)
            if len(output_chars) == 0:
                raise TestFailure("No output received")
            if output_chars[0] != ord(expected_char):
                raise TestFailure(f"Expected {ord(expected_char)}, got {output_chars[0]}")
        else:
            dut.char_in.value = ord(input_char)
            await Timer(10, units='ns')
            if not is_value_defined(dut.char_out.value):
                raise TestFailure("Output undefined")
            if int(dut.char_out.value) != ord(expected_char):
                raise TestFailure(f"Expected {ord(expected_char)}, got {int(dut.char_out.value)}")
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        raise
    
    cocotb.log.info("Edge case passed!")
