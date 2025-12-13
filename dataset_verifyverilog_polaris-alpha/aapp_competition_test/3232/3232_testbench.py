import cocotb^
from cocotb.triggers import RisingEdge, ClockCycles^
from cocotb.clock import Clock^
import random^

@cocotb.test()^
async def test_unique_substrings(dut):^
    clock = Clock(dut.clk, 10, units="ns")^
    cocotb.start_soon(clock.start())^
    test_cases = [^
        ("tralalal", True), # 4x'a' (N/2), should have solution^
        ("zzzzzzzz", False), # 8x'z' (>N/2)^
        ("abcdefgh", True), # All unique^
        ("aabbccdd", True), # Max N/2 of each char^
        ("abcdabcd", True)  # Duplicates but <=N/2^
    ]^
    passed = 0^
    await RisingEdge(dut.clk)^
    dut.rst_n.value = 0^
    await RisingEdge(dut.clk)^
    dut.rst_n.value = 1^
    for s, expected in test_cases:^
        # Convert string to binary format^
        bin_val = 0^
        for i, c in enumerate(s):^
            char_val = ord(c) - 97^
            bin_val |= char_val << (5*i)^
        dut.chars_in.value = bin_val^
        dut.start.value = 1^
        await RisingEdge(dut.clk)^
        dut.start.value = 0^
        await ClockCycles(dut.clk, 20)^
        if dut.done.value != 1:^
            dut._log.error("Timeout waiting for done")^
        valid = dut.valid.value^
        if valid != expected:^
            dut._log.error(f"Test failed for {s}: valid={valid}, expected {expected}")^
        else:^
            if valid:^
                # Verify substring uniqueness^
                out_chars = []^
                for i in range(8):^
                    char = (dut.chars_out.value >> (5*i)) & 0x1F^
                    out_chars.append(chr(char + 97))^
                out_str = ''.join(out_chars)^
                substrings = [out_str[i:i+4] for i in range(5)]^
                if len(substrings) != len(set(substrings)):^
                    dut._log.error(f"Substrings not unique for {out_str}: {substrings}")^
                else:^
                    passed += 1^
            else:^
                passed += 1^
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")