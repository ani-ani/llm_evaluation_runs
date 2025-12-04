import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_autocorrect(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define small dictionary (8 words, 8 char max, 5 bits per char)
    def str_to_bits(s):
        bits = 0
        for i, c in enumerate(s.ljust(8)):
            if i >= 8: break
            val = ord(c) - ord('a') if c != ' ' else 31
            bits |= (val & 0x1F) << (5*i)
        return bits
    
    # Test case 1: Reduced sample input
    dictionary = [
        str_to_bits("autocorrect"),  # Most common
        str_to_bits("austria"),
        str_to_bits("program"),
        str_to_bits("programming"),
        str_to_bits("computer"),
        str_to_bits(""),
        str_to_bits(""),
        str_to_bits("")  # Unused entries
    ]
    
    test_cases = [
        ("autocorrelation", 12),  # Original sample
        ("programming", 4),
        ("austria", 2),  # Exact match
        ("p", 1)  # Type 1 char only
    ]
    
    # Initialize and reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    passed = 0
    for i, (word, expected) in enumerate(test_cases):
        # Load dictionary and target word
        for j in range(8):
            dut.dictionary[j].value = dictionary[j]
        dut.target_word.value = str_to_bits(word)
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 3 cycles for result
        await ClockCycles(dut.clk, 3)
        
        # Verify output
        if dut.keystrokes.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test {i+1} failed: {word} gave {dut.keystrokes.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")