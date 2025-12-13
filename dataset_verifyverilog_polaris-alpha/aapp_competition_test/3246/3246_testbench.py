import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_word_descrambler(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test cases (scrambled_str, dict_words, expected_output, expected_status)
    test_cases = [
        (
            b"tihs    ", # 'this' (4 chars) + padding
            [b"this    ", b"test    ", b"word    "], 
            b"this      ", 
            1, # word_count
            4, # output_length
            1  # status: done
        ),
        (
            b"hitehre ", # 6 chars ('hithere' = ambiguous)
            [b"hi     ", b"there  ", b"three  "],
            b"          ", 
            3, # word_count
            0, # output_length
            3  # status: ambiguous
        ),
        (
            b"abcd    ", # No match
            [b"test    ", b"word    "],
            b"          ", 
            2, # word_count
            0, # output_length
            3  # status: impossible
        )
    ]
    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    passed = 0
    for idx, (scrambled, words, expect_out, word_cnt, out_len, expect_stat) in enumerate(test_cases):
        # Load inputs
        dut.scrambled_str.value = int.from_bytes(scrambled, 'big')
        for i in range(8):
            if i < len(words):
                dut.dict_words[i].value = int.from_bytes(words[i], 'big')
            else:
                dut.dict_words[i].value = 0
        dut.word_count.value = word_cnt
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for processing
        cycles = 0
        while dut.status.value == 0 and cycles < 300:
            await RisingEdge(dut.clk)
            cycles += 1
        # Verify outputs
        if dut.status.value != expect_stat:
            dut._log.error(f"Test {idx} failed: status={dut.status.value} (expected {expect_stat})")
        elif expect_stat == 1: # Valid output case
            out_bytes = dut.deciphered_str.value.buffer.tobytes()
            if out_bytes[:out_len] != expect_out[:dut.output_length.value]:
                dut._log.error(f"Test {idx} failed: got '{out_bytes.decode().strip()}' expected '{expect_out.decode().strip()}'")
            else:
                passed += 1
        else: 
            if dut.status.value == expect_stat:
                passed += 1
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
