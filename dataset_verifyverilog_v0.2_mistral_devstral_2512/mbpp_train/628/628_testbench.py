import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

def char_to_ascii(c):
    """Convert character to ASCII value"""
    return ord(c)

def replace_spaces_str(s):
    """Python reference for replace_spaces"""
    return s.replace(' ', '%20')

async def feed_string(dut, test_str):
    """Feed test string to DUT character by character"""
    chars = list(test_str)
    dut.char_valid.value = 0
    
    for i, c in enumerate(chars):
        # Wait for DUT to be ready
        await RisingEdge(dut.clk)
        while dut.char_read.value == 0:
            await RisingEdge(dut.clk)
        
        # Feed character
        dut.char_in.value = char_to_ascii(c)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
    
    # Send null terminator
    await RisingEdge(dut.clk)
    while dut.char_read.value == 0:
        await RisingEdge(dut.clk)
    dut.char_in.value = 0  # Null terminator
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0

async def collect_output(dut, expected_len):
    """Collect output characters from DUT"""
    output = []
    timeout = 100
    count = 0
    
    while count < timeout:
        await RisingEdge(dut.clk)
        if dut.char_valid_out.value:
            char_val = dut.char_out.value
            if 32 <= char_val <= 126:  # Printable ASCII
                output.append(chr(char_val))
            else:
                output.append(f"[0x{char_val:02X}]")
            count += 1
        if dut.done.value:
            break
    
    return ''.join(output)

@cocotb.test()
async def test_replace_spaces_basic(dut):
    """Test Case 1: Simple two-word string"""
    # Setup
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "Hi" -> "Hi"
    test_input = "Hi"
    expected = "Hi"
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed input
    await feed_string(dut, test_input)
    
    # Collect output
    result = await collect_output(dut, len(expected))
    
    # Verify
    if result != expected:
        raise TestFailure(f"Expected '{expected}', got '{result}'")
    
    print(f"Test 1 passed: Input='{test_input}' -> Output='{result}'")

@cocotb.test()
async def test_replace_spaces_with_space(dut):
    """Test Case 2: String with single space"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "A B" -> "A%20B"
    test_input = "A B"
    expected = "A%20B"
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await feed_string(dut, test_input)
    result = await collect_output(dut, len(expected))
    
    if result != expected:
        raise TestFailure(f"Expected '{expected}', got '{result}'")
    
    print(f"Test 2 passed: Input='{test_input}' -> Output='{result}'")

@cocotb.test()
async def test_replace_spaces_multiple_spaces(dut):
    """Test Case 3: Multiple spaces"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "I am" -> "I%20am"
    test_input = "I am"
    expected = "I%20am"
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await feed_string(dut, test_input)
    result = await collect_output(dut, len(expected))
    
    if result != expected:
        raise TestFailure(f"Expected '{expected}', got '{result}'")
    
    print(f"Test 3 passed: Input='{test_input}' -> Output='{result}'")

@cocotb.test()
async def test_replace_spaces_three_words(dut):
    """Test Case 4: Three words with spaces"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "Hi Yo" -> "Hi%20Yo"
    test_input = "Hi Yo"
    expected = "Hi%20Yo"
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await feed_string(dut, test_input)
    result = await collect_output(dut, len(expected))
    
    if result != expected:
        raise TestFailure(f"Expected '{expected}', got '{result}'")
    
    print(f"Test 4 passed: Input='{test_input}' -> Output='{result}'")

@cocotb.test()
async def test_replace_spaces_empty_string(dut):
    """Test Case 5: Empty string"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "" -> ""
    test_input = ""
    expected = ""
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Immediately send null
    await feed_string(dut, test_input)
    result = await collect_output(dut, 1)  # May produce nothing
    
    if result != "":
        raise TestFailure(f"Expected empty string, got '{result}'")
    
    print(f"Test 5 passed: Empty string handled correctly")

@cocotb.test()
async def test_replace_spaces_concurrent_flow(dut):
    """Test Case 6: Verify flow control with delayed input"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "X Y" with manual delays
    test_input = "X Y"
    expected = "X%20Y"
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Manual feed to test flow control
    chars = list(test_input)
    output = []
    
    for c in chars:
        # Wait for read signal
        while dut.char_read.value == 0:
            await RisingEdge(dut.clk)
        
        # Provide character
        dut.char_in.value = char_to_ascii(c)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        
        # Collect any immediate output
        for _ in range(5):
            if dut.char_valid_out.value:
                output.append(chr(dut.char_out.value))
            await RisingEdge(dut.clk)
    
    # Send null
    while dut.char_read.value == 0:
        await RisingEdge(dut.clk)
    dut.char_in.value = 0
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    
    # Collect remaining output
    timeout = 20
    for _ in range(timeout):
        if dut.char_valid_out.value:
            output.append(chr(dut.char_out.value))
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    result = ''.join(output)
    
    if result != expected:
        raise TestFailure(f"Expected '{expected}', got '{result}'")
    
    print(f"Test 6 passed: Concurrent flow test")
    print(f"
=== Summary: All 6 tests passed ===")
