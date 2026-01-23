import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_move_num_basic(dut):
    """Test basic digit and non-digit separation"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0x00
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 'I1love143you' (12 chars) padded to 16 with 0x00
    # Expected: 'Iloveyou1143' + 4x0x00
    test_str = 'I1love143you'
    expected = 'Iloveyou'
    expected_digits = '1143'
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Send 16 characters (12 real + 4 padding)
    chars = [ord(c) for c in test_str] + [0x00] * 4
    
    for i, char in enumerate(chars):
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.char_in.value = char
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for output to start (after 16 input cycles)
    # Collect 16 output characters
    output_chars = []
    
    for i in range(32):
        await RisingEdge(dut.clk)
        if dut.valid_out.value and dut.char_out.value != 0x00:
            output_chars.append(chr(dut.char_out.value))
    
    output_str = ''.join(output_chars)
    
    # Should contain all non-digits then digits
    print(f"Test 1: Input='{test_str}', Output='{output_str}'")
    
    # Extract non-digit and digit parts
    non_digit_part = ''.join([c for c in output_str if not c.isdigit()])
    digit_part = ''.join([c for c in output_str if c.isdigit()])
    
    if non_digit_part != expected or digit_part != expected_digits:
        raise TestFailure(f"Expected non-digits='{expected}', digits='{expected_digits}', got '{non_digit_part}', '{digit_part}'")

@cocotb.test()
async def test_move_num_all_digits(dut):
    """Test with only digits"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_str = '1234567890ABCD'  # 10 digits + 4 non-digits
    expected_digits = '1234567890'
    expected_nondigits = 'ABCD'
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    chars = [ord(c) for c in test_str]
    for char in chars:
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.char_in.value = char
    
    # 2 more padding chars
    for _ in range(2):
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.char_in.value = 0x00
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output_chars = []
    for i in range(32):
        await RisingEdge(dut.clk)
        if dut.valid_out.value and dut.char_out.value != 0x00:
            output_chars.append(chr(dut.char_out.value))
    
    output_str = ''.join(output_chars)
    
    non_digit_part = ''.join([c for c in output_str if not c.isdigit()])
    digit_part = ''.join([c for c in output_str if c.isdigit()])
    
    if non_digit_part != expected_nondigits or digit_part != expected_digits:
        raise TestFailure(f"All digits test: Expected non='{expected_nondigits}', dig='{expected_digits}', got '{non_digit_part}', '{digit_part}'")

@cocotb.test()
async def test_move_num_no_digits(dut):
    """Test with no digits"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_str = 'HelloWorldTest'  # 14 chars
    expected = 'HelloWorldTest'
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    chars = [ord(c) for c in test_str] + [0x00] * 2
    for char in chars:
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.char_in.value = char
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output_chars = []
    for i in range(32):
        await RisingEdge(dut.clk)
        if dut.valid_out.value and dut.char_out.value != 0x00:
            output_chars.append(chr(dut.char_out.value))
    
    output_str = ''.join(output_chars)
    
    print(f"Test 3: Input='{test_str}', Output='{output_str}'")
    
    if output_str != expected:
        raise TestFailure(f"No digits test: Expected '{expected}', got '{output_str}'")

@cocotb.test()
async def test_move_num_full_16_chars(dut):
    """Test with exactly 16 mixed characters"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 16 chars: A1B2C3D4E5F6G7H8
    test_str = 'A1B2C3D4E5F6G7H8'
    expected_nondigits = 'ABCDEFGH'
    expected_digits = '12345678'
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    chars = [ord(c) for c in test_str]
    for char in chars:
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.char_in.value = char
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output_chars = []
    for i in range(32):
        await RisingEdge(dut.clk)
        if dut.valid_out.value and dut.char_out.value != 0x00:
            output_chars.append(chr(dut.char_out.value))
    
    output_str = ''.join(output_chars)
    
    non_digit_part = ''.join([c for c in output_str if not c.isdigit()])
    digit_part = ''.join([c for c in output_str if c.isdigit()])
    
    print(f"Test 4: Input='{test_str}', Output='{output_str}'")
    
    if non_digit_part != expected_nondigits or digit_part != expected_digits:
        raise TestFailure(f"Full 16 chars: Expected non='{expected_nondigits}', dig='{expected_digits}', got '{non_digit_part}', '{digit_part}'")

@cocotb.test()
async def test_move_num_empty(dut):
    """Test with all padding (empty input)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(16):
        await RisingEdge(dut.clk)
        dut.valid_in.value = 1
        dut.char_in.value = 0x00
    
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output_chars = []
    for i in range(32):
        await RisingEdge(dut.clk)
        if dut.valid_out.value and dut.char_out.value != 0x00:
            output_chars.append(chr(dut.char_out.value))
    
    output_str = ''.join(output_chars)
    
    print(f"Test 5: Empty input, Output='{output_str}'")
    
    if len(output_str) > 0:
        raise TestFailure(f"Empty test: Expected empty output, got '{output_str}'")
