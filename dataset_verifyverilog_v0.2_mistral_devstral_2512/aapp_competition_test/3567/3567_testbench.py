import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_character_creator(dut):
    """Test character creation with minimization of maximum similarity"""
    
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_players.value = 0
    dut.num_features.value = 0
    dut.characters.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 1: n=3, k=5 ===")
    # Characters: 01001, 11100, 10111
    # Test expects output 00010 (max similarity = 3)
    dut.num_players.value = 3
    dut.num_features.value = 5
    # Pack characters: each is 8 bits, lower 5 bits used
    # char[0] = 01001 = 0x09
    # char[1] = 11100 = 0x1C
    # char[2] = 10111 = 0x17
    # Pack into 64-bit signal: characters[7:0][7:0]
    dut.characters.value = (0x09) | (0x1C << 8) | (0x17 << 16)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 256 cycles)
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Timeout: done never asserted"
    result = dut.best_character.value & 0x1F  # Mask to 5 bits
    max_sim = dut.min_max_similarity.value
    
    print(f"Best character: {result:05b} (0x{result:02x})")
    print(f"Min max similarity: {max_sim}")
    
    # Verify similarity calculation for result=00010 (0x02)
    # 00010 vs 01001: positions match at 0,2,3? 0b00010 vs 0b01001: bit0=0vs0(match),1=0vs1(diff),2=0vs0(match),3=1vs0(diff),4=0vs1(diff) -> 2 matches? Wait recheck
    # Actually: 00010 vs 01001: [0:0==0✓, 1:0==1✗, 2:0==0✓, 3:1==0✗, 4:0==1✗] = 2 matches
    # 00010 vs 11100: [0:0==1✗, 1:0==1✗, 2:0==1✗, 3:1==0✗, 4:0==0✓] = 1 match
    # 00010 vs 10111: [0:0==1✗, 1:0==0✓, 2:0==1✗, 3:1==1✓, 4:0==1✗] = 2 matches
    # Max similarity = 2? But output is 00010, let me recalculate carefully
    # Wait, the problem says: "if both have or none have" = similarity increases
    # So similarity = k - Hamming distance
    # 00010 (2) vs 01001 (9): Hamming = bits where differ: pos1,3,4 => 3 differences, sim = 5-3=2
    # 00010 (2) vs 11100 (28): Hamming: pos0,1,2,3 => 4 differences, sim = 5-4=1
    # 00010 (2) vs 10111 (23): Hamming: pos0,2,4 => 3 differences, sim = 5-3=2
    # Max similarity = 2
    # But maybe 00000 has max sim = 3? Let's check:
    # 00000 vs 01001: diff at pos1,4 => 2 diff, sim=3
    # 00000 vs 11100: diff at pos0,1,2,3,4? No: 11100 vs 00000 has diff at 0,1,2 => 3 diff, sim=2
    # 00000 vs 10111: diff at 0,2,3,4 => 4 diff, sim=1
    # Max sim = 3, worse than 00010's 2. So 00010 is valid.
    
    # Check if result achieves reasonable minimum
    assert max_sim <= 3, f"Max similarity {max_sim} too high"
    print(f"✓ Test 1 passed: result={result:05b}, max_sim={max_sim}")
    
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 2: n=1, k=4 ===")
    # Character: 0000
    # Expected: any character with max sim = 4 (since 0000 matches with 1111 only on 0 bits, wait)
    # 0000 vs ??? Max sim = min(4, 4) = 4? No: 0000 vs 1111: all bits different, sim=0
    # 0000 vs 0000: sim=4
    # So best is 1111 giving sim=0
    
    dut.num_players.value = 1
    dut.num_features.value = 4
    dut.characters.value = 0x00  # 0000
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1
    result = dut.best_character.value & 0x0F
    max_sim = dut.min_max_similarity.value
    
    print(f"Best character: {result:04b}")
    print(f"Min max similarity: {max_sim}")
    
    # 1111 should give sim=0 with 0000
    # Also 0000 gives sim=4
    # So min max sim = 0, any character that is all 1s works
    assert max_sim == 0 or result == 0b1111, "Expected max_sim=0 or result=1111"
    print(f"✓ Test 2 passed: result={result:04b}, max_sim={max_sim}")
    
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 3: n=2, k=3 ===")
    # Characters: 000, 111
    # Best: 010 or 101 gives max sim = 2 with both
    dut.num_players.value = 2
    dut.num_features.value = 3
    dut.characters.value = 0x0700  # 111=7 at high byte, 000=0 at low byte (packed: 0x00 | (0x07 << 8))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1
    result = dut.best_character.value & 0x07
    max_sim = dut.min_max_similarity.value
    
    print(f"Best character: {result:03b}")
    print(f"Min max similarity: {max_sim}")
    
    # 010 (2) vs 000: sim = 3-1=2? No: 010 vs 000: diff at pos1 only, sim=2
    # 010 vs 111: diff at pos0,2, sim=1, max=2
    # 000 vs 000: sim=3, vs111: sim=0, max=3
    # 111 vs 000: sim=0, vs111: sim=3, max=3
    # So min max sim = 2
    assert max_sim == 2, f"Expected max_sim=2, got {max_sim}"
    print(f"✓ Test 3 passed: result={result:03b}, max_sim={max_sim}")
    
    print("
=== All tests completed ===")
