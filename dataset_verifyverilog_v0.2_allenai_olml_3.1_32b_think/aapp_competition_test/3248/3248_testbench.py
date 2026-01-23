import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def to_ascii(char):
    return ord(char)

@cocotb.test()
async def test_untileable_cells(dut):
    """Test the untileable_cells module"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: "abcbab" with patterns "cb", "cbab" -> 2 untileable
    # Street: a b c b a b (indices 0-5)
    # Pattern "cb" (len 2): matches at index 2 -> covers 2,3
    # Pattern "cbab" (len 4): matches at index 2 -> covers 2,3,4,5
    # Covered: index 0 (a), 1 (b) are NOT covered. Indices 2-5 are covered.
    # Result should be 2.
    
    street = "abcbab"
    patterns = ["cb", "cbab"]
    
    dut.N_valid.value = len(street)
    dut.M_valid.value = len(patterns)
    
    # Set street chars
    for i in range(16):
        char = to_ascii(street[i]) if i < len(street) else 0
        getattr(dut, f'street_char_{i}').value = char
    
    # Set patterns
    for p_idx in range(8):
        if p_idx < len(patterns):
            pat = patterns[p_idx]
            pat_len = len(pat)
            getattr(dut, f'pattern_len_{p_idx}').value = pat_len
            for c_idx in range(16):
                char = to_ascii(pat[c_idx]) if c_idx < pat_len else 0
                getattr(dut, f'pattern_{p_idx}_char_{c_idx}').value = char
        else:
            getattr(dut, f'pattern_len_{p_idx}').value = 0
            for c_idx in range(16):
                getattr(dut, f'pattern_{p_idx}_char_{c_idx}').value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module did not finish in time"
    assert dut.result.value == 2, f"Expected 2, got {dut.result.value}"
    print(f"Test 1 Passed: Result {dut.result.value}")
    
    # Test case 2: "abab" with patterns "bac", "baba" -> 4 untileable
    # Street: a b a b (indices 0-3)
    # Pattern "bac" (len 3): Checks positions 0 and 1. 
    #   Position 0: 'aba' != 'bac'
    #   Position 1: 'bab' != 'bac'
    # Pattern "baba" (len 4): Checks position 0. 'abab' != 'baba'
    # No matches. All 4 cells untileable.
    
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    street = "abab"
    patterns = ["bac", "baba"]
    
    dut.N_valid.value = len(street)
    dut.M_valid.value = len(patterns)
    
    for i in range(16):
        char = to_ascii(street[i]) if i < len(street) else 0
        getattr(dut, f'street_char_{i}').value = char
    
    for p_idx in range(8):
        if p_idx < len(patterns):
            pat = patterns[p_idx]
            pat_len = len(pat)
            getattr(dut, f'pattern_len_{p_idx}').value = pat_len
            for c_idx in range(16):
                char = to_ascii(pat[c_idx]) if c_idx < pat_len else 0
                getattr(dut, f'pattern_{p_idx}_char_{c_idx}').value = char
        else:
            getattr(dut, f'pattern_len_{p_idx}').value = 0
            for c_idx in range(16):
                getattr(dut, f'pattern_{p_idx}_char_{c_idx}').value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module did not finish in time"
    assert dut.result.value == 4, f"Expected 4, got {dut.result.value}"
    print(f"Test 2 Passed: Result {dut.result.value}")
    
    # Test case 3: "abcabc" with patterns "abca", "cab" -> 1 untileable
    # Street: a b c a b c (indices 0-5)
    # Pattern "abca" (len 4): matches at index 0 -> covers 0,1,2,3
    # Pattern "cab" (len 3): matches at index 3 -> covers 3,4,5
    # Covered: 0,1,2,3,4,5. Wait, let's re-read example.
    # Sample Output 3 is 1.
    # Let's re-check pattern matching.
    # Street: a b c a b c
    # "abca": matches at 0 -> a b c a. Covers 0,1,2,3.
    # "cab": matches at index 3 -> street[3:6] = a b c. Wait, "cab" is c a b.
    # Street index 3 is 'a'. 'a' != 'c'.
    # Wait, let's check index 2: street[2:5] = c a b. Matches "cab"! Covers 2,3,4.
    # Covered indices: 
    # From "abca" (start 0): 0, 1, 2, 3
    # From "cab" (start 2): 2, 3, 4
    # Union: 0, 1, 2, 3, 4. Index 5 ('c') is NOT covered?
    # Wait. If index 2 is covered, that is 'c'.
    # Is there a pattern covering index 5?
    # Street: a b c a b c
    # Indices: 0 1 2 3 4 5
    # Covered: 0, 1, 2, 3, 4. Index 5 is missing.
    # Result 1.
    
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    street = "abcabc"
    patterns = ["abca", "cab"]
    
    dut.N_valid.value = len(street)
    dut.M_valid.value = len(patterns)
    
    for i in range(16):
        char = to_ascii(street[i]) if i < len(street) else 0
        getattr(dut, f'street_char_{i}').value = char
    
    for p_idx in range(8):
        if p_idx < len(patterns):
            pat = patterns[p_idx]
            pat_len = len(pat)
            getattr(dut, f'pattern_len_{p_idx}').value = pat_len
            for c_idx in range(16):
                char = to_ascii(pat[c_idx]) if c_idx < pat_len else 0
                getattr(dut, f'pattern_{p_idx}_char_{c_idx}').value = char
        else:
            getattr(dut, f'pattern_len_{p_idx}').value = 0
            for c_idx in range(16):
                getattr(dut, f'pattern_{p_idx}_char_{c_idx}').value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Module did not finish in time"
    assert dut.result.value == 1, f"Expected 1, got {dut.result.value}"
    print(f"Test 3 Passed: Result {dut.result.value}")
    
    print("All tests passed!")
