import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def adverb_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    test_cases = [
        # (input_text, expected_start, expected_end, expected_word)
        ("Clearly, he has no excuse for such behavior.", 0, 7, "Clearly"),
        ("Please handle the situation carefuly", 28, 36, "carefuly"),
        ("quickly", 0, 6, "quickly"),
        ("Normal text without target", -1, -1, ""),
        ("ly", 0, 2, "ly")
    ]
    
    # Convert strings to 64-byte packed format
    def str_to_bits(s):
        bytes_val = s.encode('ascii').ljust(64, b'\\0')
        return int.from_bytes(bytes_val, 'big')
    
    dut._log.info("Initialize and reset")
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for idx, (text_in, exp_start, exp_end, exp_word) in enumerate(test_cases):
        dut.text.value = str_to_bits(text_in)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        timeout = 0
        while dut.done.value == 0 and timeout < 70:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 70:
            dut._log.error(f"Test {idx} timed out")
            continue
        
        # Extract found word bytes
        word_bytes = bytes.fromhex(f"{dut.found_word.value.integer:08x}")
        found_str = word_bytes.decode('ascii').rstrip('\\x00')
        
        if exp_start == -1:  # No match expected
            if dut.valid.value == 0:
                passed += 1
                dut._log.info(f"PASS {idx}: Correct non-detection")
            else:
                dut._log.error(f"FAIL {idx}: False positive at {dut.start_pos.value}-{dut.end_pos.value}: {found_str}")
        else:
            if (dut.start_pos.value == exp_start and 
                dut.end_pos.value == exp_end and
                found_str == exp_word and
                dut.valid.value == 1):
                passed += 1
                dut._log.info(f"PASS {idx}: {exp_word} at {exp_start}-{exp_end}")
            else:
                dut._log.error(f"FAIL {idx}: Got {found_str} at {dut.start_pos.value}-{dut.end_pos.value}, expected {exp_word} at {exp_start}-{exp_end}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")