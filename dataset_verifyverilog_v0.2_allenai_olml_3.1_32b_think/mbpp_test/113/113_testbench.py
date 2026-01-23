import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_check_integer(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_idx.value = 0
    dut.valid_char.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 1: 'python' (should be False) ===")
    # 'python' as 8-char: p(0x70), y(0x79), t(0x74), h(0x68), o(0x6F), n(0x6E), null, null
    chars = [0x70, 0x79, 0x74, 0x68, 0x6F, 0x6E, 0x00, 0x00]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(8):
        dut.char_idx.value = i
        dut.char_in.value = chars[i]
        dut.valid_char.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1 or dut.result.value != 0:
        raise TestFailure(f"Test 1 failed: expected result=0, got {int(dut.result.value)}")
    print("Test 1 passed: 'python' correctly identified as invalid")
    
    print("
=== Test 2: '1' (should be True) ===")
    # '1' as 8-char: '1'(0x31), nulls
    chars = [0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(8):
        dut.char_idx.value = i
        dut.char_in.value = chars[i]
        dut.valid_char.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1 or dut.result.value != 1:
        raise TestFailure(f"Test 2 failed: expected result=1, got {int(dut.result.value)}")
    print("Test 2 passed: '1' correctly identified as valid")
    
    print("
=== Test 3: '12345' (should be True) ===")
    # '12345' as 8-char: '1'(0x31),'2'(0x32),'3'(0x33),'4'(0x34),'5'(0x35), nulls
    chars = [0x31, 0x32, 0x33, 0x34, 0x35, 0x00, 0x00, 0x00]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(8):
        dut.char_idx.value = i
        dut.char_in.value = chars[i]
        dut.valid_char.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1 or dut.result.value != 1:
        raise TestFailure(f"Test 3 failed: expected result=1, got {int(dut.result.value)}")
    print("Test 3 passed: '12345' correctly identified as valid")
    
    print("
=== Test 4: '-123' (should be True) ===")
    # '-123' as 8-char: '-'(0x2D),'1'(0x31),'2'(0x32),'3'(0x33), nulls
    chars = [0x2D, 0x31, 0x32, 0x33, 0x00, 0x00, 0x00, 0x00]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(8):
        dut.char_idx.value = i
        dut.char_in.value = chars[i]
        dut.valid_char.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1 or dut.result.value != 1:
        raise TestFailure(f"Test 4 failed: expected result=1, got {int(dut.result.value)}")
    print("Test 4 passed: '-123' correctly identified as valid")
    
    print("
=== Test 5: '+abc' (should be False) ===")
    # '+abc' as 8-char: '+'(0x2B),'a'(0x61),'b'(0x62),'c'(0x63), nulls
    chars = [0x2B, 0x61, 0x62, 0x63, 0x00, 0x00, 0x00, 0x00]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(8):
        dut.char_idx.value = i
        dut.char_in.value = chars[i]
        dut.valid_char.value = 1
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    if dut.done.value != 1 or dut.result.value != 0:
        raise TestFailure(f"Test 5 failed: expected result=0, got {int(dut.result.value)}")
    print("Test 5 passed: '+abc' correctly identified as invalid")
    
    print("
=== All tests completed ===")
    print("Summary: 5/5 tests passed")