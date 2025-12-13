import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def string_to_words(s):
    words = s.strip().split(' ')[:4]
    word_bytes = [bytes(word.ljust(16, ' '), 'ascii') for word in words]
    packed = b''.join(word_bytes[::-1])
    return int.from_bytes(packed, 'big'), len(words)

@cocotb.test()
async def test_splitter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        ("python programming ", ['python','programming']),  # Original Test 1
        ("lists    tuples   ", ['lists','tuples']),      # Modified Test 2
        ("write a program   ", ['write','a','program']), # Original Test 3
        ("singleword        ", ['singleword']),         # Edge case 1
        ("                ", [])                       # Edge case 2
    ]

    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for input_str, expected_words in test_cases:
        # Prepare input
        input_bytes = input_str.ljust(16, ' ').encode('ascii')
        input_val = int.from_bytes(input_bytes, 'big')
        exp_word_data, exp_count = string_to_words(input_str)

        # Apply input
        dut.str_in.value = input_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for processing
        for _ in range(16):
            await RisingEdge(dut.clk)

        # Check outputs
        await RisingEdge(dut.clk)  # Wait for done assertion
        assert dut.done.value == 1, "Done signal not asserted"
        
        if dut.word_count.value == exp_count and dut.words_out.value == exp_word_data:
            passed += 1
            dut._log.info(f"PASS: '{input_str}' → {expected_words}")
        else:
            dut._log.error(f"FAIL: '{input_str}'")
            dut._log.error(f"  Expected: {exp_count} words, data=0x{exp_word_data:0128x}")
            dut._log.error(f"  Received: {dut.word_count.value} words, data=0x{dut.words_out.value.integer:0128x}")
        
        await RisingEdge(dut.clk)
        assert dut.done.value == 0, "Done should pulse for 1 cycle"

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)