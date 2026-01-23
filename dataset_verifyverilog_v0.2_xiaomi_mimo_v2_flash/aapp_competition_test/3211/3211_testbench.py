import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_voting_optimizer(dut):
    """Test voting optimizer with various scenarios"""
    
    # Test case 1: Sample Input 1 adapted (8 citizens: 12210020)
    # Original: 1 2 2 1 0 0 2 0
    # Swaps needed: 4
    # In 3-bit encoding: 1=001, 2=010, 0=100
    test_cases = [
        # (expected_min_swaps, expected_possible, n, [citizens])
        (4, 1, 8, [1,2,2,1,0,0,2,0]),  # Original: 12210020 -> 4 swaps
        (15, 0, 4, [1,1,1,1]),          # Original: 1111 -> impossible (no tellers)
        (5, 1, 8, [0,0,2,1,1,2,2,2]),   # Adapted from test 3: 00211222 -> needs check
    ]
    
    for idx, (expected_swaps, expected_possible, n, citizens_list) in enumerate(test_cases):
        print(f"
Test case {idx+1}: n={n}, citizens={citizens_list}")
        
        # Setup inputs
        dut.n.value = n
        for i in range(8):
            if i < n:
                val = citizens_list[i]
                if val == 1:
                    dut.citizens[i].value = 0b001
                elif val == 2:
                    dut.citizens[i].value = 0b010
                else:  # val == 0
                    dut.citizens[i].value = 0b100
            else:
                dut.citizens[i].value = 0b000  # Padding
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        min_swaps = int(dut.min_swaps.value)
        win_possible = int(dut.win_possible.value)
        
        print(f"  Expected: swaps={expected_swaps}, possible={expected_possible}")
        print(f"  Got:      swaps={min_swaps}, possible={win_possible}")
        
        # Check results
        if win_possible != expected_possible:
            raise TestFailure(f"Test {idx+1}: Possible flag mismatch. Expected {expected_possible}, got {win_possible}")
        
        if expected_possible and min_swaps != expected_swaps:
            raise TestFailure(f"Test {idx+1}: Swaps mismatch. Expected {expected_swaps}, got {min_swaps}")
    
    print("
=== Summary ===")
    print(f"All {len(test_cases)} test cases passed.")
