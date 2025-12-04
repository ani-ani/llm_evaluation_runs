import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_word_splitter(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await Timer(5, units='ns')
        dut.rst_n.value = 1
        dut.start.value = 0

    def str_to_bits(s):
        bits = 0
        for i,c in enumerate(s.ljust(16)):
            bits |= ord(c) << (8*(15-i))
        return bits

    def parse_output(words, count):
        result = []
        for i in range(count):
            word_bits = (words >> (i*128)) & ((1<<128)-1)
            chars = [chr((word_bits >> (8*(15-j))) & 0xff) for j in range(16)]
            clean_word = ''.join(chars).split('\\0')[0]
            result.append(clean_word.strip())
        return result

    await reset()
    passed = 0
    test_cases = [
        ("Hi, my name    ", ["Hi", "my", "name"]),
        ("One,two,three  ", ["One", "two", "three"]),
        ("Ahmed,Gamal    ", ["Ahmed", "Gamal"]),
        ("SingleWord      ", ["SingleWord"]),
        ("                ", [])
    ]

    for input_str, expected in test_cases:
        dut._log.info(f"Testing: '{input_str}' -> {expected}")
        dut.ascii_str.value = str_to_bits(input_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        output = parse_output(dut.words.value, dut.word_count.value)
        
        if dut.word_count.value != len(expected):
            dut._log.error(f"FAIL: Expected {len(expected)} words, got {dut.word_count.value}
" 
                           f"Full output: {output}")
        else:
            match = all(a == b for a,b in zip(output, expected))
            if match:
                passed += 1
                dut._log.info(f"PASS: {input_str} -> {output}")
            else:
                dut._log.error(f"FAIL: {input_str} -> {output}, expected {expected}")
        
        await RisingEdge(dut.clk)
        if dut.done.value:
            dut._log.error("FAIL: Done signal didn't clear")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)