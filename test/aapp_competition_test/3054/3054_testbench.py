import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_haiku(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (word, expected_syllables)[, ...]
    test_cases = [
        { # Valid haiku (3 words)
            "words": [[ord(c) for c in "Hello       "], 
                      [ord(c) for c in "world!      "], 
                      [ord(c) for c in "testing.    "], 
                      [0]*12, [0]*12, [0]*12, [0]*12, [0]*12], 
            "word_count": 3, 
            "expected": {"is_haiku": 0} # Syllables: 2,1,2 (total 5)
        },
        { # Valid haiku (5 words)
            "words": [[ord(c) for c in "Cat         "], 
                      [ord(c) for c in "sat         "], 
                      [ord(c) for c in "mat         "], 
                      [ord(c) for c in "Peacefully  "], 
                      [ord(c) for c in "sleeping.   "], 
                      [0]*12, [0]*12, [0]*12], 
            "word_count": 5, 
            "expected": {"is_haiku": 1, "line_breaks": 0b011} 
        }
    ]

    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    passed = 0
    for case in test_cases:
        dut.start.value = 0
        dut.word_count.value = case["word_count"]
        for i in range(8):
            for j in range(12):
                dut.words[i][j].value = case["words"][i][j]
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        if dut.is_haiku.value == case["expected"]["is_haiku"]:
            passed += 1
        else:
            dut._log.error("Haiku detection failed")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
