import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Rule encoding: 32 bits = Head(8) + Prod0(8) + Prod1(8) + Prod2(8)
# Heads: 'S' = 0x53, 'A' = 0x41, etc.
# Prod: 'a' = 0x61, 'b' = 0x62, empty = 0xFF

def encode_rule(head, prod):
    """Encode rule: head char, prod string (max 3 chars)"""
    h = ord(head) << 24
    p = 0
    for i, c in enumerate(prod[:3]):
        p |= ord(c) << (16 - i*8)
    if len(prod) == 0:
        p = 0xFFFFFFFF >> 8  # 0xFFFFFF
    elif len(prod) == 1:
        p = (ord(prod[0]) << 16) | 0xFFFF
    elif len(prod) == 2:
        p = (ord(prod[0]) << 16) | (ord(prod[1]) << 8) | 0xFF
    return h | p

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cfg_search(dut):
    # Setup clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'char_in'):
        dut.char_in.value = 0
    if has_signal(dut, 'cfg_rules'):
        dut.cfg_rules.value = 0
    if has_signal(dut, 'input_len'):
        dut.input_len.value = 0
    if has_signal(dut, 'text_mode'):
        dut.text_mode.value = 0
    
    for _ in range(2):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    
    # Test Case 1: Palindrome grammar, input "abaaba"
    # Grammar: S->aSa, S->bSb, S->a, S->b, S->ε
    # Expected: "abaaba" (length 6)
    
    rules = [
        ('S', 'aSa'),
        ('S', 'bSb'),
        ('S', 'a'),
        ('S', 'b'),
        ('S', ''),
    ]
    
    # Load rules (assuming sequential load interface or one-shot)
    # Here we simulate loading rules into a memory or shift register
    # For simplicity, we'll assume `cfg_rules` can take packed values
    if has_signal(dut, 'cfg_rules'):
        # Load first rule
        dut.cfg_rules.value = encode_rule('S', 'aSa')
        dut.text_mode.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait a few cycles for internal config
        await Timer(50, units='ns')
    
    # Load text
    if has_signal(dut, 'text_mode'):
        dut.text_mode.value = 1
    
    text = "abaaba"
    if has_signal(dut, 'input_len'):
        dut.input_len.value = len(text)
    
    # Feed characters sequentially (assuming serial input)
    if has_signal(dut, 'char_in'):
        for char in text:
            dut.char_in.value = ord(char)
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await RisingEdge(dut.clk)  # Assume implicit handshake
    
    # Start processing
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for done
    found = False
    for i in range(200):  # Max cycles
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                found = True
                break
        else:
            # If no done signal, assume combinatorial or timeout
            pass
    
    if not found:
        raise TestFailure("Timeout waiting for done")
    
    # Read results
    if has_signal(dut, 'result_start') and has_signal(dut, 'result_len'):
        start_idx = int(dut.result_start.value)
        length = int(dut.result_len.value)
        
        # Extract substring
        if length > 0 and start_idx + length <= len(text):
            substring = text[start_idx:start_idx + length]
            print(f"Match: '{substring}' at {start_idx}, len {length}")
            
            if substring != "abaaba":
                raise TestFailure(f"Expected 'abaaba', got '{substring}'")
        else:
            if length != 0:
                raise TestFailure(f"Invalid result indices: start={start_idx}, len={length}")
            else:
                raise TestFailure("No match found for 'abaaba'")
    
    # Test Case 2: "none on this line" -> NONE
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    
    text = "none on this line"
    if has_signal(dut, 'input_len'):
        dut.input_len.value = len(text)
    
    if has_signal(dut, 'char_in'):
        for char in text:
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait
    for _ in range(200):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                break
    
    if has_signal(dut, 'result_len'):
        length = int(dut.result_len.value)
        if length != 0:
            raise TestFailure(f"Expected no match, but got length {length}")
    
    # Test Case 3: "a" -> "a"
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    
    text = "a"
    if has_signal(dut, 'input_len'):
        dut.input_len.value = len(text)
    
    if has_signal(dut, 'char_in'):
        dut.char_in.value = ord('a')
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await RisingEdge(dut.clk)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait
    for _ in range(200):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                break
    
    if has_signal(dut, 'result_start') and has_signal(dut, 'result_len'):
        start_idx = int(dut.result_start.value)
        length = int(dut.result_len.value)
        
        if length == 1 and start_idx == 0:
            print(f"Match: '{text}' at 0, len 1")
        else:
            raise TestFailure(f"Expected 'a' at 0, len 1, got start={start_idx}, len={length}")

    print("All tests passed!")
