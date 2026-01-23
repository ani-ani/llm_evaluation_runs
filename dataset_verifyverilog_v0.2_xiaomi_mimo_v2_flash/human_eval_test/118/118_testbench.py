import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_closest_vowel(dut):
    """Test the closest_vowel module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.word.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to pack string into integer (little endian)
    def pack_word(s):
        val = 0
        for i, c in enumerate(s):
            val |= (ord(c) << (8*i))
        return val

    # Test cases
    test_cases = [
        ("yogurt", "u"),
        ("FULL", "U"),
        ("quick", ""),
        ("ab", ""),
        ("ba", ""),
        ("bad", "a"),
        ("most", "o"),
        ("anime", "i"),
        ("Asia", ""),
        ("Above", "o"),
        ("full", "u"),
        ("easy", ""),
        ("eAsy", ""),
        ("ali", "")
    ]
    
    passed = 0
    total = len(test_cases)
    
    for word, expected in test_cases:
        # Pad word to 8 chars if needed (or truncate if longer)
        padded_word = word[:8].ljust(8, '\x00')
        dut.word.value = pack_word(padded_word)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20 # Max cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        res = chr(dut.result.value)
        if expected == "":
            # Expect 0 (null byte)
            if dut.result.value == 0:
                passed += 1
            else:
                print(f"FAIL: Word '{word}'. Expected 0, got {res} (val {dut.result.value})")
        else:
            if res == expected:
                passed += 1
            else:
                print(f"FAIL: Word '{word}'. Expected '{expected}', got '{res}'")
        
        # Small delay between tests
        await Timer(10, units='ns')

    print(f"
{passed}/{total} tests passed")
    assert passed == total
