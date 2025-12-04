import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def str_to_bits(s, length=64):
    # Convert string to 512-bit ASCII representation
    padded = s.ljust(length, '\\0')
    return int.from_bytes(padded.encode('ascii'), 'big')

def extract_word(text_bits, start, end):
    # Extract substring from 512-bit ASCII representation
    total_bits = 512
    byte_start = total_bits//8 - end
    byte_end = total_bits//8 - start
    bytes_val = (text_bits >> (byte_start*8)) & ((1 << ((byte_end-byte_start)*8))-1)
    return bytes_val.to_bytes(end-start, 'big').decode('ascii').rstrip('\\x00')

@cocotb.test()
async def test_adverb_finder(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        ("clearly!! we can see the sky", 0, 7, "clearly"),
        ("seriously!! there") + " "*48, 0, 9, "seriously"),
        ("unfortunately!! sita") + " "*44, 0, 13, "unfortunately"),
        ("test promptly done") + " "*46, 5, 12, "promptly"),
        ("noadverbshere") + " "*51, None, None, None)  # No match case
    ]

    passed = 0
    for idx, (text, exp_start, exp_end, exp_word) in enumerate(test_cases):
        # Setup input
        dut.text.value = str_to_bits(text)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Decode outputs
        actual_start = dut.start_pos.value.integer
        actual_end = dut.end_pos.value.integer
        actual_word = extract_word(int(dut.found_word.value), 0, min(actual_end-actual_start, 16))
        
        # Verify
        if exp_word is None:
            if actual_start == 0 and actual_end == 0:
                passed += 1
                dut._log.info(f"PASS {idx}: Correctly detected no adverb")
            else:
                dut._log.error(f"FAIL {idx}: False positive {actual_word} at ({actual_start},{actual_end})")
        else:
            if (actual_start == exp_start and 
                actual_end == exp_end and
                actual_word == exp_word):
                passed += 1
                dut._log.info(f"PASS {idx}: Found '{actual_word}' at ({actual_start},{actual_end})")
            else:
                dut._log.error(f"FAIL {idx}: Expected '{exp_word}' at ({exp_start},{exp_end}), got '{actual_word}' at ({actual_start},{actual_end})")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")