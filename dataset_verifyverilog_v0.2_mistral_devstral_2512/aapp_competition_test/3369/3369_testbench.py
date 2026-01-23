import cocotb
from cocotb.triggers import Timer
import random

def to_fixed_array(seq_str):
    """Converts space-separated string to a list of integers."""
    parts = seq_str.strip().split()
    # Pad with zeros if less than 16
    nums = [int(p) for p in parts]
    while len(nums) < 16:
        nums.append(0)
    return nums[:16]

@cocotb.test()
async def test_triple_correlation(dut):
    """Test the triple correlation detector with provided examples and edge cases."""
    
    # Test Case 1: The example from the problem description (first 16 digits)
    # Sequence: 4 7 9 5 9 3 5 0 0 1 7 8 5 0 2 6
    # We need to check if 4(1)4(3)3 is present.
    # Looking at the sequence: indices 0:4, 1:7... 
    # The example output says 4(1)4(3)3 is found.
    # Let's manually check a snippet of the full 100 digit sequence provided:
    # 4 7 9 5 9 3 5 0 0 1 7 8 5 0 2 6 3 5 4 4 4 6 3 3 ...
    # Indices: 16:3, 17:5, 18:4, 19:4, 20:4, 21:6, 22:3, 23:3...
    # Wait, let's re-read the example. "whenever a 4 is followed immediately by another 4, the third value after this will be a 3"
    # This means 4(1)4(3)3. 
    # In the sample sequence: `... 5 4 4 4 6 3 3 ...`
    # Indices (relative to start of this snippet): 
    # If we look at indices 18 and 19 in the 100-digit string: 4, 4. 
    # Index 18 is 4. Index 19 is 4. 
    # Third value after this (distance 3 from the second 4) is index 19+3 = 22. Index 22 is 3. 
    # So 4 (at 18), 4 (at 19), 3 (at 22) matches 4(1)4(3)3.
    
    # Let's construct a 16-digit sequence that IS guaranteed to have 4(1)4(3)3.
    # We need: index i=4, index i+1=4, index i+1+3=3.
    # i=0: seq[0]=4, seq[1]=4, seq[4]=3.
    seq1 = [4, 4, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    dut.seq.value = seq1
    await Timer(10, units='ns')
    
    found = int(dut.found.value)
    a = int(dut.a.value)
    b_val = int(dut.b.value)
    c = int(dut.c.value)
    n_val = int(dut.n.value)
    m_val = int(dut.m.value)
    
    # Expected: 4(1)4(3)3
    assert found == 1, f"Test 1 Failed: Expected correlation found=1, got {found}"
    assert a == 4, f"Test 1 Failed: Expected a=4, got {a}"
    assert n_val == 1, f"Test 1 Failed: Expected n=1, got {n_val}"
    assert b_val == 4, f"Test 1 Failed: Expected b=4, got {b_val}"
    assert m_val == 3, f"Test 1 Failed: Expected m=3, got {m_val}"
    assert c == 3, f"Test 1 Failed: Expected c=3, got {c}"
    print(f"Test 1 Passed: Found {a}({n_val}){b_val}({m_val}){c}")

    # Test Case 2: Random sequence (10 digits given, we pad to 16)
    # "1 2 3 1 2 2 1 1 3 0" + 6 zeros
    seq2 = [1, 2, 3, 1, 2, 2, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0]
    dut.seq.value = seq2
    await Timer(10, units='ns')
    
    found = int(dut.found.value)
    assert found == 0, f"Test 2 Failed: Expected random sequence (found=0), got {found}"
    print("Test 2 Passed: Correctly identified as random")

    # Test Case 3: Pattern with multiple matches, test priority
    # Construct: 5(0)5(0)5 at index 0 and 2(1)2(2)2 at index 1.
    # Sequence: 5, 5, 5, 2, 2, 2, 0, 0...
    # 5(0)5(0)5 -> a=5, n=0, b=5, m=0, c=5. This occurs at index 0 (seq[0]=5, seq[0]=5, seq[0]=5). 
    # 2(1)2(2)2 -> a=2, n=1, b=2, m=2, c=2. This occurs at index 1 (seq[1]=2, seq[2]=2, seq[4]=2).
    # Earliest index is 0 (for 5). So 5(0)5(0)5 should win.
    # However, we must ensure these patterns strictly follow the rules.
    # Rule 1 for 5(0)5(0)5: If seq[i]==5 and seq[i]==5, then seq[i]==5. OK.
    # Rule 2 for 5(0)5(0)5: If seq[i]==5 and seq[i]==5, then seq[i]==5. OK.
    # Rule 3 for 5(0)5(0)5: If seq[i]==5 and seq[i]==5, then seq[i]==5. OK.
    
    seq3 = [5, 5, 5, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    dut.seq.value = seq3
    await Timer(10, units='ns')
    
    found = int(dut.found.value)
    a = int(dut.a.value)
    n_val = int(dut.n.value)
    
    # We expect the earliest one (5 at index 0)
    assert found == 1, "Test 3 Failed: Expected correlation found"
    assert a == 5, f"Test 3 Failed: Expected earliest pattern (a=5), got {a}"
    assert n_val == 0, f"Test 3 Failed: Expected smallest n (0), got {n_val}"
    print(f"Test 3 Passed: Priority logic correct. Found {a}({n_val})...")

    # Test Case 4: Boundary case where n+m is large
    # 1(0)2(7)3 at index 0. Needs indices 0, 0, 7. Sequence length 16. 0+0+7=7 < 16. OK.
    seq4 = [1, 0, 0, 0, 0, 0, 0, 3, 2, 0, 0, 0, 0, 0, 0, 0]
    # To satisfy Rule 1: 1 at 0, 2 at 0 (wait, b is 2? No, pattern is 1(0)2(7)3).
    # a=1, n=0, b=2, m=7, c=3.
    # Rule 1: seq[0]==1, seq[0]==2? No. Seq[0]=1. Seq[0]=1 != 2.
    # So this specific pattern isn't valid in this sequence. 
    # Let's try 0(7)2(0)3? 
    # Let's stick to a simple valid one: 1(0)1(0)1 if seq is all 1s.
    # Or test 1(5)2(0)3. 
    # seq[0]=1, seq[5]=2, seq[5]=3. Impossible.
    # Let's just test a simple one to ensure large n/m work.
    # 1(5)2(0)3 -> seq[0]=1, seq[5]=2, seq[5]=3. Impossible.
    # 1(5)2(2)3 -> seq[0]=1, seq[5]=2, seq[7]=3.
    seq4 = [1, 0, 0, 0, 0, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0]
    dut.seq.value = seq4
    await Timer(10, units='ns')
    
    found = int(dut.found.value)
    # 1(5)2(2)3 is valid.
    assert found == 1, "Test 4 Failed"
    print("Test 4 Passed: Larger n/m values handled")

    print("All tests passed!")
