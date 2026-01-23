import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def test_abab_pattern_finder(dut):
    """Test ABAB pattern detection with lexicographic ordering"""
    
    # Initialize inputs
    dut.N.value = 0
    for i in range(16):
        dut.S[i].value = 0
    
    await Timer(10, units='ns')
    
    # Test Case 1: From problem - S = [1,3,2,4,1,5,2,4] -> A=1, B=2
    # Pattern: S[0]=1, S[2]=2, S[4]=1, S[6]=2 -> 1,2,1,2
    print("
Test Case 1: [1,3,2,4,1,5,2,4] -> Expected: 1 2")
    dut.N.value = 8
    test_seq = [1, 3, 2, 4, 1, 5, 2, 4]
    for i, val in enumerate(test_seq):
        dut.S[i].value = val
    
    await Timer(10, units='ns')
    
    A_val = int(dut.A.value)
    B_val = int(dut.B.value)
    valid_val = int(dut.valid.value)
    
    print(f"  Result: A={A_val}, B={B_val}, valid={valid_val}")
    assert valid_val == 1, f"Expected valid=1, got {valid_val}"
    assert A_val == 1, f"Expected A=1, got {A_val}"
    assert B_val == 2, f"Expected B=2, got {B_val}"
    
    # Test Case 2: No ABAB pattern - S = [1,2,3,4,5,6,7,1]
    # All 1s are at indices 0 and 7, but no B appears twice with A in between
    print("
Test Case 2: [1,2,3,4,5,6,7,1] -> Expected: -1")
    dut.N.value = 8
    test_seq = [1, 2, 3, 4, 5, 6, 7, 1]
    for i, val in enumerate(test_seq):
        dut.S[i].value = val
    
    await Timer(10, units='ns')
    
    valid_val = int(dut.valid.value)
    
    print(f"  Result: valid={valid_val}")
    assert valid_val == 0, f"Expected valid=0, got {valid_val}"
    
    # Test Case 3: S = [2,1,2,1] -> A=2, B=1 (lexicographically smallest pair with A=2, B=1)
    # Pattern: indices 0,1,2,3 -> 2,1,2,1
    # But check lexicographic order: (1,2) would be smaller than (2,1)
    # Does (1,2) exist? S[1]=1, S[?]=2 after 1, S[?]=1 after that, S[?]=2
    # No, because there's only one 1 at index 1, and one 2 at index 0 and 2
    # Actually: A=1 appears at index 1 only, so can't have 1,?,1,?
    # A=2 appears at indices 0 and 2. B=1 appears at index 1 and 3
    # Pattern: S[0]=2, S[1]=1, S[2]=2, S[3]=1 -> 2,1,2,1
    # So A=2, B=1 is the only pattern. Output: 2 1
    print("
Test Case 3: [2,1,2,1] -> Expected: 2 1")
    dut.N.value = 4
    test_seq = [2, 1, 2, 1]
    for i, val in enumerate(test_seq):
        dut.S[i].value = val
    
    await Timer(10, units='ns')
    
    A_val = int(dut.A.value)
    B_val = int(dut.B.value)
    valid_val = int(dut.valid.value)
    
    print(f"  Result: A={A_val}, B={B_val}, valid={valid_val}")
    assert valid_val == 1, f"Expected valid=1, got {valid_val}"
    assert A_val == 2, f"Expected A=2, got {A_val}"
    assert B_val == 1, f"Expected B=1, got {B_val}"
    
    # Test Case 4: Multiple valid patterns, choose lexicographically smallest
    # S = [3,1,3,2,1,2] (N=6)
    # Pattern (1,2): S[1]=1, S[3]=2, S[4]=1, S[5]=2 -> valid
    # Pattern (3,1): S[0]=3, S[1]=1, S[2]=3, S[4]=1 -> valid but (1,2) is smaller
    print("
Test Case 4: [3,1,3,2,1,2] -> Expected: 1 2")
    dut.N.value = 6
    test_seq = [3, 1, 3, 2, 1, 2]
    for i, val in enumerate(test_seq):
        dut.S[i].value = val
    
    await Timer(10, units='ns')
    
    A_val = int(dut.A.value)
    B_val = int(dut.B.value)
    valid_val = int(dut.valid.value)
    
    print(f"  Result: A={A_val}, B={B_val}, valid={valid_val}")
    assert valid_val == 1, f"Expected valid=1, got {valid_val}"
    assert A_val == 1, f"Expected A=1, got {A_val}"
    assert B_val == 2, f"Expected B=2, got {B_val}"
    
    # Test Case 5: All same values - no pattern
    print("
Test Case 5: [1,1,1,1] -> Expected: -1")
    dut.N.value = 4
    test_seq = [1, 1, 1, 1]
    for i, val in enumerate(test_seq):
        dut.S[i].value = val
    
    await Timer(10, units='ns')
    
    valid_val = int(dut.valid.value)
    
    print(f"  Result: valid={valid_val}")
    assert valid_val == 0, f"Expected valid=0, got {valid_val}"
    
    # Test Case 6: Edge case with values 16
    # S = [16,1,16,2,1,2] (N=6)
    # Pattern (1,2) exists: S[1]=1, S[3]=2, S[4]=1, S[5]=2
    print("
Test Case 6: [16,1,16,2,1,2] -> Expected: 1 2")
    dut.N.value = 6
    test_seq = [16, 1, 16, 2, 1, 2]
    for i, val in enumerate(test_seq):
        dut.S[i].value = val
    
    await Timer(10, units='ns')
    
    A_val = int(dut.A.value)
    B_val = int(dut.B.value)
    valid_val = int(dut.valid.value)
    
    print(f"  Result: A={A_val}, B={B_val}, valid={valid_val}")
    assert valid_val == 1, f"Expected valid=1, got {valid_val}"
    assert A_val == 1, f"Expected A=1, got {A_val}"
    assert B_val == 2, f"Expected B=2, got {B_val}"
    
    print("
=== All 6 tests passed! ===")
