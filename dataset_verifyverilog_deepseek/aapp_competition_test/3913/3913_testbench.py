import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_word_guess(dut):
    # Initialize
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.word_valid.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: orig 4
a**d
2
abcd
acbd (expect 2)
    def char_to_bits(c):
        if c == '*': return 0b000000
        return (1 << 5) | (ord(c) - ord('a'))
    
    revealed = ['a', '*', '*', 'd'] + ['*']*12
    revealed_bits = 0
    for i, c in enumerate(reversed(revealed)):
        revealed_bits = (revealed_bits << 6) | char_to_bits(c)

    words = [
        list('abcd') + ['a']*12,
        list('acbd') + ['a']*12,
    ]

    # Apply inputs
    dut.n.value = 4
    dut.revealed_chars.value = revealed_bits
    dut.m.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Feed words
    for word in words:
        word_bits = 0
        for c in reversed(word):
            word_bits = (word_bits << 5) | (ord(c) - ord('a'))
        dut.word_data.value = word_bits
        dut.word_valid.value = 1
        await RisingEdge(dut.clk)
    dut.word_valid.value = 0

    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.result.value == 2, "Test 1 failed"

    # Test Case 2: 5
lo*er
2
lover
loser (expect 0)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    revealed = ['l','o','*','e','r'] + ['*']*11
    revealed_bits = 0
    for c in reversed(revealed):
        revealed_bits = (revealed_bits << 6) | char_to_bits(c)
    words = [list('lover')+['a']*11, list('loser')+['a']*11]
    dut.n.value = 5
    dut.revealed_chars.value = revealed_bits
    dut.m.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for word in words:
        word_bits = 0
        for c in reversed(word):
            word_bits = (word_bits << 5) | (ord(c) - ord('a'))
        dut.word_data.value = word_bits
        dut.word_valid.value = 1
        await RisingEdge(dut.clk)
    dut.word_valid.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    assert dut.result.value == 0, "Test 2 failed"

    # Print results
    dut._log.info("2/2 tests passed")