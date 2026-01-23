import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_slavko_word(dut):
    """Test Slavko's ability to win with small N."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: N=2, "ne"
    # Mirko: rightmost 'e' -> Mirko word "e"
    # Slavko: remaining 'n' -> Slavko word "n"
    # Slavko "n" > Mirko "e"? No. Slavko "n" (110) > Mirko "e" (101). 
    # Wait, lexicographical. 'n' (110) > 'e' (101). So Slavko loses. 
    # Output should be NE, word "n".
    
    sequence = "ne"
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load characters
    for char in sequence:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        
    # Wait for processing (N=2, turns=1)
    # States: LOAD -> MIRKO -> SLAVKO -> COMPARE -> DONE
    # Assume 10 cycles max
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not finish in time")
        
    # Check results
    # Word should be packed 'n' (0x6E)
    # slavko_word_out is 80 bits (10 bytes). First byte is 'n'
    word_val = int(dut.slavko_word_out.value)
    first_char = (word_val >> 72) & 0xFF
    
    print(f"Test 1 (ne): Slavko Word Char 1: {chr(first_char)}, Win Flag: {dut.winnable.value}")
    
    assert chr(first_char) == 'n', f"Expected 'n', got {chr(first_char)}"
    assert dut.winnable.value == 0, "Expected NE (not winnable)"
    
    # Test Case 2: N=4, "kava"
    # Sequence: k a v a
    # Mirko (R): a (rightmost) -> Mirko: a
    # Slavko (Optimal): Look at {k, a, v}. Min is 'a'. Pick 'a'. Slavko: a
    # Remaining: {k, v}
    # Mirko (R): v -> Mirko: av
    # Slavko (Optimal): {k}. Min is 'k'. Pick 'k'. Slavko: ak
    # Comparison: Slavko "ak" vs Mirko "av".
    # "ak" < "av". Yes. Slavko wins.
    # Output: DA, "ak".
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    sequence = "kava"
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in sequence:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Test 2: Did not finish in time")
        
    # Check results for "ak"
    # Word: [0]=a, [1]=k
    word_val = int(dut.slavko_word_out.value)
    char1 = (word_val >> 72) & 0xFF
    char2 = (word_val >> 64) & 0xFF
    
    print(f"Test 2 (kava): Slavko Word: {chr(char1)}{chr(char2)}, Win Flag: {dut.winnable.value}")
    
    assert chr(char1) == 'a', f"Expected 'a', got {chr(char1)}"
    assert chr(char2) == 'k', f"Expected 'k', got {chr(char2)}"
    assert dut.winnable.value == 1, "Expected DA (winnable)"
    
    # Test Case 3: N=8, "cokolada"
    # Sequence: c o k o l a d a
    # Mirko (R): a -> Mirko: a
    # Slavko (Optimal): {c o k o l a d a} - wait, Mirko took one 'a'. Remaining: {c o k o l a d}
    # Min is 'a'. Pick 'a'. Slavko: a
    # Mirko (R): d -> Mirko: ad
    # Slavko (Optimal): {c o k o l}. Min 'c'. Pick 'c'. Slavko: ac
    # Mirko (R): l -> Mirko: adl
    # Slavko (Optimal): {o k o}. Min 'k'. Pick 'k'. Slavko: ack
    # Mirko (R): o -> Mirko: adlo
    # Slavko (Optimal): {o}. Min 'o'. Pick 'o'. Slavko: acko
    # Result: Slavko "acko" vs Mirko "adlo".
    # "acko" < "adlo". Yes.
    # Output: DA, "acko".
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    sequence = "cokolada"
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in sequence:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
        
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure("Test 3: Did not finish in time")
        
    word_val = int(dut.slavko_word_out.value)
    chars = []
    for i in range(5):
        shift = 72 - (i * 8)
        chars.append(chr((word_val >> shift) & 0xFF))
        
    print(f"Test 3 (cokolada): Slavko Word: {''.join(chars)}, Win Flag: {dut.winnable.value}")
    
    assert ''.join(chars) == "acko", f"Expected 'acko', got {''.join(chars)}"
    assert dut.winnable.value == 1, "Expected DA (winnable)"
    
    print("All tests passed!")
