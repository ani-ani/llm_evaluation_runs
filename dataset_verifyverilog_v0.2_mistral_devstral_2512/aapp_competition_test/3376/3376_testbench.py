import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_nudgemon_optimal_xp(dut):
    """Test Nudgémon optimal XP calculation with Blessed Egg timing"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_catches.value = 0
    dut.num_families.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 1: Sample Input ===")
    # 3 families, 7 catches
    # Family 0: 3 creatures, cost 3
    # Family 1: 3 creatures, cost 3
    # Family 2: 3 creatures, cost 1
    dut.num_families.value = 3
    dut.family_evolution_cost[0].value = 3
    dut.family_evolution_cost[1].value = 3
    dut.family_evolution_cost[2].value = 1
    dut.family_chain_length[0].value = 3
    dut.family_chain_length[1].value = 3
    dut.family_chain_length[2].value = 3
    
    # 7 catches: 0,500,1000,1500,2000,2500,3000
    # Families: electromouse(2), electromouse(2), electromouse(2), rat(2), aaabaaajss(1), pigeon(1), butterfly(1)
    dut.num_catches.value = 7
    dut.catch_times[0].value = 0
    dut.catch_family[0].value = 2
    dut.catch_times[1].value = 500
    dut.catch_family[1].value = 2
    dut.catch_times[2].value = 1000
    dut.catch_family[2].value = 2
    dut.catch_times[3].value = 1500
    dut.catch_family[3].value = 2
    dut.catch_times[4].value = 2000
    dut.catch_family[4].value = 1
    dut.catch_times[5].value = 2500
    dut.catch_family[5].value = 1
    dut.catch_times[6].value = 3000
    dut.catch_family[6].value = 1
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (100 cycles)
    for _ in range(105):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    
    # Expected: 5100 XP = 0x0013F800 in Q16.16
    # 5100 * 65536 = 334,188,800 = 0x13F80000
    expected_xp = 0x13F80000
    actual_xp = int(dut.max_xp.value)
    
    print(f"Expected XP (Q16.16): 0x{expected_xp:08X} ({expected_xp})")
    print(f"Actual XP (Q16.16):   0x{actual_xp:08X} ({actual_xp})")
    print(f"XP Value: {actual_xp / 65536:.2f}")
    
    if actual_xp != expected_xp:
        raise TestFailure(f"XP mismatch! Expected {expected_xp}, got {actual_xp}")
    
    print("Test 1 PASSED
")
    
    # Wait a bit before next test
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    
    print("=== Test 2: Single Creature ===")
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 1 family, 2 catches of same creature
    # Expected: 2 catches = 200 base, but 300 seconds apart
    # If window captures both: 2*200 + candies=6, cost=1, max evolutions=6 -> 6*1000=6000, total=6400
    # But sample output is 300, so let's adjust
    # Actually: 1 family with 1 creature (no evolution possible)
    # 2 catches at t=0 and t=1800, window [0,1800) catches 1, [1800,3600) catches 1
    # Each gives 200 XP, so max is 200? But sample says 300
    # Wait, sample input shows: "1 slownudge" with 2 catches at 0 and 1800
    # If window [0,1800): catch at 0 gives 200, catch at 1800 is outside
    # If window [1800,3600): catch at 1800 gives 200
    # But output is 300... 
    # Re-reading: "1 slownudge" means 1 creature in family, no evolution possible
    # 2 catches: if both in window, 2*200=400, but sample says 300
    # Perhaps: the 1800 catch is exactly at boundary? Or maybe window can be [0,1800] inclusive?
    # Let's assume window [0,1800) catches at t=0 only (200 XP) and t=1800 is outside
    # But output is 300... Maybe I misinterpret
    # Alternative: Maybe it's catching at t=0, evolving during [0,1800), but no evolution possible
    # Let's re-read problem: "1 slownudge" with 2 catches
    # Maybe there IS evolution? No, chain length 1 means no evolution
    # Perhaps: The 300 comes from: catch at 0 (100 doubled=200) + catch at 1800 (100 NOT doubled=100) if window is [0,1800)?
    # But catch at 1800 is at boundary e+1800, so not doubled
    # So if window is [0,1800): catch at 0 doubled=200, catch at 1800 not doubled=100, total=300
    # Yes! So window that starts at 0 captures catch at 0 (doubled) and catch at 1800 (not doubled)
    # Wait, catch at 1800 is at exactly e+1800, so NOT doubled
    # So total: 200 + 100 = 300
    
    dut.num_families.value = 1
    dut.family_evolution_cost[0].value = 0  # No evolution
    dut.family_chain_length[0].value = 1
    
    dut.num_catches.value = 2
    dut.catch_times[0].value = 0
    dut.catch_family[0].value = 0
    dut.catch_times[1].value = 1800
    dut.catch_family[1].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(105):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1
    
    # 300 XP = 0x0012C000 in Q16.16 (300 * 65536 = 19,660,800)
    expected_xp = 19660800  # 300 * 65536
    actual_xp = int(dut.max_xp.value)
    
    print(f"Expected XP (Q16.16): 0x{expected_xp:08X} ({expected_xp})")
    print(f"Actual XP (Q16.16):   0x{actual_xp:08X} ({actual_xp})")
    print(f"XP Value: {actual_xp / 65536:.2f}")
    
    if actual_xp != expected_xp:
        raise TestFailure(f"XP mismatch! Expected {expected_xp}, got {actual_xp}")
    
    print("Test 2 PASSED
")
    
    print("=== Test 3: Edge Case - No Catches ===")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_families.value = 2
    dut.family_evolution_cost[0].value = 5
    dut.family_evolution_cost[1].value = 3
    dut.family_chain_length[0].value = 2
    dut.family_chain_length[1].value = 3
    dut.num_catches.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(105):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1
    
    expected_xp = 0  # No catches = 0 XP
    actual_xp = int(dut.max_xp.value)
    
    print(f"Expected XP: 0, Actual XP: {actual_xp / 65536:.2f}")
    
    if actual_xp != 0:
        raise TestFailure(f"XP should be 0, got {actual_xp}")
    
    print("Test 3 PASSED
")
    
    print("=== All 3/3 tests passed ===")
    print("Summary: 3/3 tests passed")