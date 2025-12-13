import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import binascii

def str_to_bits(s, length):
    padded = s.ljust(length, '\0')
    return int.from_bytes(padded.encode('ascii'), 'little')

@cocotb.test()
async def test_string_matcher(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (text, pattern, found, pattern_match, start, end)
    test_cases = [
        ('The quick brown fox jumps over the lazy dog.', 'fox',  1, 'fox', 16, 19),
        ('Its been a very crazy procedure right',       'crazy',1, 'crazy',16,21),
        ('Hardest choices required strongest will',     'will', 1, 'will', 35,39),
        ('No match here',                              'xyz',   0, '',     0, 0),
        ('Test empty pattern',                         '',      0, '',     0, 0)
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for text, pattern, exp_found, exp_pat, exp_start, exp_end in test_cases:
        # Skip test if pattern longer than 8 chars
        if len(pattern) > 8:
            continue

        text_bits = str_to_bits(text[:64], 64)
        pat_bits = str_to_bits(pattern[:8], 8)

        dut.text.value = text_bits
        dut.pattern.value = pat_bits
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)  # Wait 2 cycles
        
        if dut.done.value != 1:
            dut._log.error(f"Test '{pattern}': Done signal not set")
            continue

        if int(dut.found.value) != exp_found:
            dut._log.error(f"Test '{pattern}': found={int(dut.found.value)} expected={exp_found}")
            continue

        if exp_found:
            # Convert matched pattern to string
            match_bytes = int(dut.matched_pattern.value).to_bytes(8, 'little')
            match_str = match_bytes.split(b'\0')[0].decode('ascii')
            
            if match_str != exp_pat:
                dut._log.error(f"Pattern mismatch: got '{match_str}' expected '{exp_pat}'")
                continue
            
            if int(dut.start_idx.value) != exp_start or int(dut.end_idx.value) != exp_end:
                dut._log.error(f"Index mismatch: got ({int(dut.start_idx.value)},{int(dut.end_idx.value)}) expected ({exp_start},{exp_end})")
                continue
            
            passed += 1
            dut._log.info(f"PASS: '{pattern}' @ {exp_start}-{exp_end}")
        else:
            passed += 1
            dut._log.info(f"PASS: '{pattern}' not found")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"Failed {len(test_cases)-passed} tests"