import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase

@cocotb.test()
async def test_std_counter_basic(dut):
    """Test basic functionality with simple cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: "std" -> 1 occurrence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    # Send 's','t','d','\0'
    dut.char_in.value = ord('s')  # 0x73
    await RisingEdge(dut.clk)
    dut.char_in.value = ord('t')  # 0x74
    await RisingEdge(dut.clk)
    dut.char_in.value = ord('d')  # 0x64
    await RisingEdge(dut.clk)
    dut.char_in.value = 0  # null terminator
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 1, f"Test 1 failed: expected 1, got {int(dut.count.value)}"
    print(f"Test 1 passed: 'std' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 2: "stds" -> 1 occurrence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    for char in ['s','t','d','s','\0']:
        dut.char_in.value = ord(char) if char != '\0' else 0
        await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 1, f"Test 2 failed: expected 1, got {int(dut.count.value)}"
    print(f"Test 2 passed: 'stds' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 3: "truststdsolensporsd" -> 1 occurrence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    test3_str = "truststdsolensporsd"
    for char in test3_str:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 1, f"Test 3 failed: expected 1, got {int(dut.count.value)}"
    print(f"Test 3 passed: '{test3_str}' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 4: Empty string -> 0 occurrences
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 0, f"Test 4 failed: expected 0, got {int(dut.count.value)}"
    print(f"Test 4 passed: '' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    print("All basic tests passed!")

@cocotb.test()
async def test_std_counter_advanced(dut):
    """Test advanced cases with multiple occurrences and edge cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: "letstdlenstdporstd" -> 3 occurrences
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    test5_str = "letstdlenstdporstd"
    for char in test5_str:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 3, f"Test 5 failed: expected 3, got {int(dut.count.value)}"
    print(f"Test 5 passed: '{test5_str}' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 6: "makestdsostdworthit" -> 2 occurrences
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    test6_str = "makestdsostdworthit"
    for char in test6_str:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 2, f"Test 6 failed: expected 2, got {int(dut.count.value)}"
    print(f"Test 6 passed: '{test6_str}' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 7: Overlapping pattern "stdstd" -> 2 occurrences
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    test7_str = "stdstd"
    for char in test7_str:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.count.value == 2, f"Test 7 failed: expected 2, got {int(dut.count.value)}"
    print(f"Test 7 passed: '{test7_str}' -> {int(dut.count.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    print("All advanced tests passed!")

@cocotb.test()
async def test_std_counter_error_handling(dut):
    """Test error handling for strings that are too long"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 8: String longer than 32 characters (35 chars) -> error should go high
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    # Send 35 'a' characters (more than max length)
    for i in range(35):
        dut.char_in.value = ord('a')
        await RisingEdge(dut.clk)
    
    # Check if error is high
    await RisingEdge(dut.clk)
    assert dut.error.value == 1, f"Test 8 failed: error should be 1 for too long string"
    print(f"Test 8 passed: 35 chars -> error={int(dut.error.value)}")
    
    # Check that done is also high
    assert dut.done.value == 1, f"Test 8 failed: done should be 1"
    print(f"Test 8 passed: done={int(dut.done.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    # Test 9: Exactly 32 characters without null terminator
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.valid_in.value = 1
    
    for i in range(32):
        dut.char_in.value = ord('a')
        await RisingEdge(dut.clk)
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.error.value == 0, f"Test 9 failed: error should be 0 for exactly 32 chars"
    assert dut.count.value == 0, f"Test 9 failed: count should be 0"
    print(f"Test 9 passed: 32 chars with no 'std' -> count={int(dut.count.value)}, error={int(dut.error.value)}")
    
    dut.valid_in.value = 0
    await RisingEdge(dut.clk)
    
    print("All error handling tests passed!")
    print("
=== Summary: All 9 tests passed! ===")
