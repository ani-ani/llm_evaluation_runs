import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure, TestSuccess
import random

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to pack string into 256-bit integer (32 bytes, little endian)
def pack_string(s):
    # s is a python string
    # Convert to bytes
    b = s.encode('ascii') if s else b''
    # Pad with zeros to 32 bytes
    if len(b) > 32:
        b = b[:32] # Truncate if too long (should not happen in test cases)
    val = 0
    for i, byte in enumerate(b):
        val |= byte << (8 * i)
    return val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_total_match(dut):
    """Test the total_match module."""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    
    # Initialize all inputs to 0
    dut.len1.value = 0
    dut.len2.value = 0
    for i in range(8):
        setattr(dut, f'list1_str{i}').value = 0
        setattr(dut, f'list2_str{i}').value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases
    # Each case: (list1_strings, list2_strings, expected_winner)
    # winner: 0 = list1, 1 = list2 (since list2 is smaller or tie goes to list1? No, spec says "same number... return first". If list2 is strictly smaller, return list2)
    # Wait, looking at examples:
    # ['hi', 'admin'] (2+5=7) vs ['hI', 'Hi'] (2+2=4) -> returns ['hI', 'Hi'] (list 2)
    # ['hi', 'admin'] (7) vs ['hi', 'hi'] (2+2=4) -> returns ['hi', 'hi'] (list 2)
    # ['hi', 'admin'] (7) vs ['hi', 'hi', 'admin', 'project'] (2+2+5+7=16) -> returns ['hi', 'admin'] (list 1)
    # ['hi', 'admin'] (7) vs ['hI', 'hi', 'hii'] (2+2+3=7) -> returns ['hI', 'hi', 'hii'] ? 
    # Wait, Example: total_match(['hi', 'admin'], ['hI', 'hi', 'hii']) == ['hi', 'admin']
    # List1: 7 chars. List2: 2+2+3=7 chars. Same. Return first (list1). Correct.
    # Example: total_match(['4'], ['1', '2', '3', '4', '5']) == ['4']
    # List1: 1. List2: 5. List1 is smaller. Return list1.
    
    # Expected result_sel: 0 for list1, 1 for list2
    test_cases = [
        ([""], [""], 2),  # Tie (0 vs 0). Spec says return first. We map tie to logic '2' or just check logic. 
                           # Prompt says: result_sel = 0 (list1), 1 (list2), 2 (tie).
        (["hi", "admin"], ["hI", "Hi"], 1), # 7 vs 4 -> List 2 wins
        (["hi", "admin"], ["hi", "hi", "admin", "project"], 0), # 7 vs 16 -> List 1 wins
        (["hi", "admin"], ["hI", "hi", "hi"], 1), # 7 vs 6 -> List 2 wins
        (["4"], ["1", "2", "3", "4", "5"], 0), # 1 vs 5 -> List 1 wins
        (["hi", "admin"], ["hI", "Hi"], 1), # 7 vs 4 -> List 2 wins
        (["hi", "admin"], ["hI", "hi", "hii"], 0), # 7 vs 7 -> Tie -> List 1
        ([], ["this"], 0), # 0 vs 4 -> List 1 wins
        (["this"], [], 1), # 4 vs 0 -> List 2 wins
        ( ["abcdefgh"], ["abcdefg"], 1), # 8 vs 7 -> List 2 wins
        ( ["abcdefgh"], ["abcdefgi"], 0), # 8 vs 8 -> Tie -> List 1
        ( ["a" * 10], ["b" * 5], 1), # 10 vs 5 -> List 2 wins
    ]

    passed = 0
    total = len(test_cases)

    for i, (l1, l2, expected_res) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {l1} vs {l2}")
        
        # Setup inputs
        dut.len1.value = len(l1)
        dut.len2.value = len(l2)
        
        # Clear all string inputs
        for k in range(8):
            setattr(dut, f'list1_str{k}').value = 0
            setattr(dut, f'list2_str{k}').value = 0
            
        # Pack strings
        for k, s in enumerate(l1):
            setattr(dut, f'list1_str{k}').value = pack_string(s)
        for k, s in enumerate(l2):
            setattr(dut, f'list2_str{k}').value = pack_string(s)
        
        # Wait a bit for inputs to settle
        await Timer(10, units='ns')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout logic
        done_found = False
        for cycle in range(2000): # Allow plenty of cycles
            if not is_value_defined(dut.done.value):
                # dut._log.warning(f"Case {i}: done is undefined")
                pass
            elif int(dut.done.value) == 1:
                done_found = True
                break
            await RisingEdge(dut.clk)
            
        if not done_found:
            raise TestFailure(f"Test {i}: Timeout waiting for done signal")
            
        # Verify Output
        if not is_value_defined(dut.result_sel.value):
            raise TestFailure(f"Test {i}: result_sel is undefined (X/Z)")
            
        actual_res = int(dut.result_sel.value)
        
        if actual_res != expected_res:
            raise TestFailure(f"Test {i} Failed: L1={l1}, L2={l2}. Expected {expected_res}, got {actual_res}")
        
        passed += 1
        dut._log.info(f"Test {i} Passed")
        
        # Wait for next cycle
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed == total:
        raise TestSuccess("All tests passed")
    else:
        raise TestFailure(f"{total - passed} tests failed")
