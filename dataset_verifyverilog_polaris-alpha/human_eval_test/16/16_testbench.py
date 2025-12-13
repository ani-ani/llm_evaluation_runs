import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

def string_to_128bit(s):
    padded = s.ljust(16, '\\0').lower()
    return int.from_bytes(padded.encode('ascii'), byteorder='big')

@cocotb.test()
async def test_distinct_char_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        ('', 0),
        ('abcde', 5),
        ('abcdeCADE', 5),  
        ('aaaaAAAAaaaa', 1),
        ('Jerry', 4),
        ('AAAaaaAA\x00\x00', 1)  # Edge case with nulls
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for test_input, expected in test_cases:
        # Prepare inputs
        input_len = min(len(test_input), 16)
        input_str = test_input[:16]
        
        dut.str_len.value = input_len
        dut.char_array.value = string_to_128bit(input_str)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles + 1)
        for _ in range(17):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.done.value == 1:
            if dut.distinct_count.value == expected:
                passed += 1
                dut._log.info(f"PASS: '{test_input}' => {dut.distinct_count.value}")
            else:
                dut._log.error(f"FAIL: '{test_input}' => {dut.distinct_count.value}, expected {expected}")
        else:
            dut._log.error(f"FAIL: Done signal not asserted")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)