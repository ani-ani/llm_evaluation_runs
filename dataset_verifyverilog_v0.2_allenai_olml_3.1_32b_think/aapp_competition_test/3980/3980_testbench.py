import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_max_beauty_permutation(dut):
    """
    Test the max_beauty_permutation module.
    The module computes a permutation maximizing XOR sum for n=15 (indices 0-15).
    """
    
    # Expected permutation: p[i] = 15 ^ i (bitwise complement for 4 bits)
    # This pairs 0 with 15, 1 with 14, ..., 7 with 8.
    # Result is 0->15, 1->14, 2->13, 3->12, 4->11, 5->10, 6->9, 7->8
    # 8->7, 9->6, 10->5, 11->4, 12->3, 13->2, 14->1, 15->0
    
    print("
Starting test_max_beauty_permutation...")
    
    # Give the combinational logic a moment to settle
    await Timer(10, units='ns')
    
    passed = 0
    total = 16
    
    for i in range(16):
        # Get the signal name for index i
        signal_name = f"p_{i}"
        
        if hasattr(dut, signal_name):
            signal = getattr(dut, signal_name)
            actual_val = int(signal.value)
            
            # Expected value: 15 ^ i
            expected_val = 15 ^ i
            
            # Log info
            print(f"Index {i}: Expected {expected_val}, Got {actual_val}")
            
            if actual_val == expected_val:
                passed += 1
            else:
                print(f"  FAILED at index {i}")
        else:
            print(f"  FAILED: Signal {signal_name} not found")
            
    print(f"
Result: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} signals matched expected values"
