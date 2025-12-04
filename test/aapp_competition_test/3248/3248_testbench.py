import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_untileable(dut):
    # Generate 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled from original)
    test_cases = [
        # Test 1: Original sample scaled (abcbab length 6)
        { 'street_len': 6, 'street': "abcbab", 'patterns': ["cb","cbab"], 'expected': 2 },
        # Test 2: Original sample (abab length 4)
        { 'street_len': 4, 'street': "abab", 'patterns': ["bac","baba"], 'expected': 4 },
        # Test 3: All covered case (abcabc with patterns)
        { 'street_len': 6, 'street': "abcabc", 'patterns': ["abca","cab"], 'expected': 1 }
    ]

    passed = 0
    for idx, tc in enumerate(test_cases):
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.street_len.value = tc['street_len']
        dut.num_patterns.value = len(tc['patterns'])
        
        # Street characters (pad to 16 chars)
        street_arr = list(tc['street'].ljust(16, '?'))
        for i in range(16):
            char_val = ord(street_arr[i]) if i < len(tc['street']) else 0
            dut.street_chars[i].value = char_val - ord('a') if 97 <= char_val <= 122 else 0
        
        # Tile patterns (only load used patterns)
        for p_idx in range(4):
            if p_idx < len(tc['patterns']):
                pat = tc['patterns'][p_idx]
                dut.tile_lens[p_idx].value = len(pat)
                for c_idx in range(16):
                    char_val = ord(pat[c_idx]) if c_idx < len(pat) else 0
                    dut.tile_patterns[p_idx][c_idx].value = char_val - ord('a') if 97 <= char_val <= 122 else 0
            else:
                dut.tile_lens[p_idx].value = 0
                for c_idx in range(16):
                    dut.tile_patterns[p_idx][c_idx].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout at 2000 cycles)
        for _ in range(2000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, f"Test case {idx} timed out"
        
        # Check output
        result = dut.untileable_count.value.integer
        if result == tc['expected']:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: Got {result}, expected {tc['expected']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")\\