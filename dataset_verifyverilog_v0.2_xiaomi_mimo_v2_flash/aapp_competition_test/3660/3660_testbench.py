import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import struct

@cocotb.test()
async def test_sticker_solver(dut):
    # Initialize clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: BUYSTICKERS
    message = "BUYSTICKERS"
    dut.message_len.value = len(message)
    for i, char in enumerate(message):
        dut.message_chars[i].value = ord(char) - ord('A')
    
    stickers = [
        ("BUYER", 10),
        ("STICKY", 10),
        ("TICKERS", 1),
        ("ERS", 8)
    ]
    dut.num_stickers.value = 4
    for i, (word, price) in enumerate(stickers):
        dut.sticker_len[i].value = len(word)
        for j, char in enumerate(word):
            dut.sticker_chars[i][j].value = ord(char) - ord('A')
        dut.sticker_price[i].value = price
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Expected 28
    assert dut.result.value == 28, f"Test 1 failed: expected 28, got {dut.result.value}"
    print("Test 1 passed")
    
    # Test Case 2: IMPOSSIBLE
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    message = "ABBBA"
    dut.message_len.value = len(message)
    for i, char in enumerate(message):
        dut.message_chars[i].value = ord(char) - ord('A')
    
    stickers = [
        ("AAAAA", 10),
        ("BB", 3)
    ]
    dut.num_stickers.value = 2
    for i, (word, price) in enumerate(stickers):
        dut.sticker_len[i].value = len(word)
        for j, char in enumerate(word):
            dut.sticker_chars[i][j].value = ord(char) - ord('A')
        dut.sticker_price[i].value = price
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Expected 0xFFFFFFFF for IMPOSSIBLE
    expected = 0xFFFFFFFF
    assert dut.result.value == expected, f"Test 2 failed: expected {expected}, got {dut.result.value}"
    print("Test 2 passed")
    
    # Additional edge cases
    # Test 3: Empty message
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.message_len.value = 0
    dut.num_stickers.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 3 failed: expected 0, got {dut.result.value}"
    print("Test 3 passed")
    
    # Test 4: Single sticker covering all
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    message = "ABCD"
    dut.message_len.value = 4
    for i, char in enumerate(message):
        dut.message_chars[i].value = ord(char) - ord('A')
    
    stickers = [("ABCD", 5)]
    dut.num_stickers.value = 1
    dut.sticker_len[0].value = 4
    for j, char in enumerate("ABCD"):
        dut.sticker_chars[0][j].value = ord(char) - ord('A')
    dut.sticker_price[0].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 5, f"Test 4 failed: expected 5, got {dut.result.value}"
    print("Test 4 passed")
    
    print("All 4 tests passed")