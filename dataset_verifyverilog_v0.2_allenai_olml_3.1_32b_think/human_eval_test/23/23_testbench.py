import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_strlen_basic(dut):
    """Test basic strlen functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.string_data.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Empty string (immediate null)
    dut.string_data.value = 0  # All zeros
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (should be 2 cycles: 1 for scan, 1 for done)
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 1: Expected done=1, got {dut.done.value}")
    if dut.length.value != 0:
        raise TestFailure(f"Test 1: Expected length=0, got {dut.length.value}")
    print("Test 1 passed: Empty string length = 0")
    
    await RisingEdge(dut.clk)
    
    # Test case 2: Single character 'x' (ASCII 0x78)
    # Format: byte 0 = 0x78, bytes 1-15 = 0x00
    dut.string_data.value = (0x78 << 120)  # 'x' at byte 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 2: Expected done=1, got {dut.done.value}")
    if dut.length.value != 1:
        raise TestFailure(f"Test 2: Expected length=1, got {dut.length.value}")
    print("Test 2 passed: Single character length = 1")
    
    await RisingEdge(dut.clk)
    
    # Test case 3: 'asdasnakj' (9 characters, ASCII: 0x61,0x73,0x64,0x61,0x73,0x6E,0x61,0x6B,0x6A)
    # Store in bytes 0-8, byte 9 = 0x00
    string_val = 0
    chars = [0x61, 0x73, 0x64, 0x61, 0x73, 0x6E, 0x61, 0x6B, 0x6A]  # 'asdasnakj'
    for i, c in enumerate(chars):
        string_val |= (c << (120 - i*8))
    dut.string_data.value = string_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 3: Expected done=1, got {dut.done.value}")
    if dut.length.value != 9:
        raise TestFailure(f"Test 3: Expected length=9, got {dut.length.value}")
    print("Test 3 passed: 'asdasnakj' length = 9")
    
    await RisingEdge(dut.clk)
    
    # Test case 4: Maximum length (16 chars, no null terminator within range)
    full_string = 0
    for i in range(16):
        full_string |= (0x41 << (120 - i*8))  # 'A' repeated 16 times
    dut.string_data.value = full_string
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 4: Expected done=1, got {dut.done.value}")
    if dut.length.value != 16:
        raise TestFailure(f"Test 4: Expected length=16, got {dut.length.value}")
    print("Test 4 passed: 16-char string length = 16")
    
    await RisingEdge(dut.clk)
    
    # Test case 5: String with embedded null (should stop at first null)
    # 'ab' + null + 'xyz' (0x61,0x62,0x00,0x78,0x79,0x7A, then zeros)
    dut.string_data.value = (0x61 << 120) | (0x62 << 112) | (0x00 << 104) | (0x78 << 96) | (0x79 << 88) | (0x7A << 80)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(17):
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 5: Expected done=1, got {dut.done.value}")
    if dut.length.value != 2:
        raise TestFailure(f"Test 5: Expected length=2, got {dut.length.value}")
    print("Test 5 passed: 'ab\x00xyz' length = 2")
    
    print("
All 5/5 tests passed!")
