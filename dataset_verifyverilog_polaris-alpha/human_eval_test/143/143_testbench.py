import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_prime_filter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted to 8-word/8-char limit
    test_cases = [
        (4, [b"This   ", b"is     ", b"a      ", b"test   "], b"is               ", [2]),
        (4, [b"lets   ", b"go     ", b"for    ", b"swimming"], b"go for            ", [2,3]),
        (2, [b"here   ", b"is     "], b"is               ", [2])
    ]
    
    passed = 0
    for word_count, words, expected, expected_lens in test_cases:
        # Load inputs
        dut.word_count.value = word_count
        for i in range(8):
            if i < len(words):
                word_val = int.from_bytes(words[i], byteorder='big')
            else:
                word_val = 0
            dut.words[i].value = word_val
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check outputs
        actual_sentence = dut.filtered_sentence.value
        expected_int = int.from_bytes(expected, byteorder='big')
        
        dut._log.info(f"Test: {words[:word_count]}")
        if (actual_sentence == expected_int and 
            dut.done.value == 1):
            passed += 1
            dut._log.info(f"PASS: Got {actual_sentence:#x}, expected {expected_int:#x}")
        else:
            dut._log.error(f"FAIL: Got {actual_sentence:#x}, expected {expected_int:#x}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")