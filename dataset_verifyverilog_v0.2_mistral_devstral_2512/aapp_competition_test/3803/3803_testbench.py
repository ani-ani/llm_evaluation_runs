import cocotb
from cocotb.triggers import Timer
import math

def calculate_min_cost(hy, ay, dy, hm, am, dm, h, a, d):
    """Calculate minimum cost using the same logic as Python solution"""
    ans = float('inf')
    # ATK purchase range: from 0 to enough to deal damage + monster HP buffer
    max_atk_buy = max(0, hm + dm - ay)  # Upper bound for useful ATK
    for A_buy in range(max_atk_buy + 1):
        final_atk = ay + A_buy
        if final_atk <= dm:
            continue  # Can't deal damage
        
        # DEF purchase range: from 0 to reduce all incoming damage
        max_def_buy = max(0, am - dy)  # Upper bound for useful DEF
        for D_buy in range(max_def_buy + 1):
            final_def = dy + D_buy
            damage_to_monster = final_atk - dm
            damage_to_yang = max(0, am - final_def)
            
            # Seconds to kill monster
            time = math.ceil(hm / damage_to_monster)
            
            # Yang's HP after battle
            hp_after = hy - time * damage_to_yang
            
            # Required additional HP
            hp_needed = max(0, 1 - hp_after)
            
            total_cost = A_buy * a + D_buy * d + hp_needed * h
            ans = min(ans, total_cost)
    
    return ans

@cocotb.test()
async def test_monster_battle(dut):
    """Test the monster battle module with multiple test cases"""
    
    test_cases = [
        # (hy, ay, dy, hm, am, dm, h, a, d, expected_cost)
        (1, 2, 1, 1, 100, 1, 1, 100, 100, 99),  # Example 1: buy 99 HP
        (100, 100, 100, 1, 1, 1, 1, 1, 1, 0),   # Example 2: no purchase needed
        (1, 10, 29, 1, 1, 43, 1, 1, 100, 34),   # Test case from input
        (1, 1, 100, 1, 1, 1, 100, 1, 100, 1),   # Edge case: high DEF
        (1, 100, 1, 1, 1, 1, 1, 1, 1, 0),       # Already strong
        (1, 1, 1, 100, 100, 100, 1, 1, 1, 19900), # Weak vs strong monster
        (50, 80, 92, 41, 51, 56, 75, 93, 12, 0), # Already wins
        (76, 63, 14, 89, 87, 35, 20, 15, 56, 915), # Complex case
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (hy, ay, dy, hm, am, dm, h, a, d, expected) in enumerate(test_cases):
        # Set inputs
        dut.yang_hp_initial.value = hy
        dut.yang_atk_initial.value = ay
        dut.yang_def_initial.value = dy
        dut.monster_hp.value = hm
        dut.monster_atk.value = am
        dut.monster_def.value = dm
        dut.cost_hp.value = h
        dut.cost_atk.value = a
        dut.cost_def.value = d
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.min_cost.value)
        
        # Verify
        expected_result = calculate_min_cost(hy, ay, dy, hm, am, dm, h, a, d)
        
        if result == expected:
            passed += 1
            print(f"Test {i+1}/{total}: PASS (cost={result})")
        else:
            print(f"Test {i+1}/{total}: FAIL - Expected {expected}, Got {result}")
            print(f"  Input: hy={hy}, ay={ay}, dy={dy}, hm={hm}, am={am}, dm={dm}, h={h}, a={a}, d={d}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} of {total} tests passed"
