import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_reverse_vowels(dut):
    """Test vowel reversal on 8-character strings"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: "Python" -> "Python" (no vowel reversal needed)
    dut._log.info("Test 1: Python")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Input "Python" padded to 8 chars: "Python  "
    input_str1 = b"Python  "
    for char in input_str1:
        dut.char_in.value = char
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Collect output over next 8 cycles
    output1 = []
    for i in range(8):
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output1.append(chr(int(dut.char_out.value)))
    
    result1 = "".join(output1)
    dut._log.info(f"Output 1: '{result1}'")
    if result1 != "Python  ":
        raise TestFailure(f"Test 1 failed: expected 'Python  ', got '{result1}'")
    
    await RisingEdge(dut.clk)
    
    # Test 2: "USA" -> "ASU"
    dut._log.info("Test 2: USA")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    input_str2 = b"USA     "
    for char in input_str2:
        dut.char_in.value = char
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output2 = []
    for i in range(8):
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output2.append(chr(int(dut.char_out.value)))
    
    result2 = "".join(output2)
    dut._log.info(f"Output 2: '{result2}'")
    if result2 != "ASU     ":
        raise TestFailure(f"Test 2 failed: expected 'ASU     ', got '{result2}'")
    
    await RisingEdge(dut.clk)
    
    # Test 3: "ab" -> "ab" (no vowels)
    dut._log.info("Test 3: ab")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    input_str3 = b"ab      "
    for char in input_str3:
        dut.char_in.value = char
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output3 = []
    for i in range(8):
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output3.append(chr(int(dut.char_out.value)))
    
    result3 = "".join(output3)
    dut._log.info(f"Output 3: '{result3}'")
    if result3 != "ab      ":
        raise TestFailure(f"Test 3 failed: expected 'ab      ', got '{result3}'")
    
    await RisingEdge(dut.clk)
    
    # Test 4: "hello" -> "holle"
    dut._log.info("Test 4: hello")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    input_str4 = b"hello   "
    for char in input_str4:
        dut.char_in.value = char
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output4 = []
    for i in range(8):
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output4.append(chr(int(dut.char_out.value)))
    
    result4 = "".join(output4)
    dut._log.info(f"Output 4: '{result4}'")
    if result4 != "holle   ":
        raise TestFailure(f"Test 4 failed: expected 'holle   ', got '{result4}'")
    
    await RisingEdge(dut.clk)
    
    # Test 5: "design" -> "disean"
    dut._log.info("Test 5: design")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    input_str5 = b"design  "
    for char in input_str5:
        dut.char_in.value = char
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    output5 = []
    for i in range(8):
        await RisingEdge(dut.clk)
        if dut.valid_out.value:
            output5.append(chr(int(dut.char_out.value)))
    
    result5 = "".join(output5)
    dut._log.info(f"Output 5: '{result5}'")
    if result5 != "disean  ":
        raise TestFailure(f"Test 5 failed: expected 'disean  ', got '{result5}'")
    
    dut._log.info("All tests passed!")