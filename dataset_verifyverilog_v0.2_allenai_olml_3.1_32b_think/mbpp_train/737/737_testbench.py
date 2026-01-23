import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_vowel_checker(dut):
    """Test vowel checker with various strings"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "annie" - starts with 'a' (vowel)
    print("Test 1: 'annie' - should start with vowel")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # First character: 'a' = 0x61
    dut.char_in.value = 0x61
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "done should be high"
    assert dut.result.value == 1, f"Expected result=1 (vowel), got {dut.result.value}"
    print("  PASSED")
    
    # Wait for next cycle
    await RisingEdge(dut.clk)
    
    # Test case 2: "dawood" - starts with 'd' (consonant)
    print("Test 2: 'dawood' - should NOT start with vowel")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # First character: 'd' = 0x64
    dut.char_in.value = 0x64
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "done should be high"
    assert dut.result.value == 0, f"Expected result=0 (consonant), got {dut.result.value}"
    print("  PASSED")
    
    # Wait for next cycle
    await RisingEdge(dut.clk)
    
    # Test case 3: "Else" - starts with 'E' (vowel)
    print("Test 3: 'Else' - should start with vowel")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # First character: 'E' = 0x45
    dut.char_in.value = 0x45
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "done should be high"
    assert dut.result.value == 1, f"Expected result=1 (vowel), got {dut.result.value}"
    print("  PASSED")
    
    # Additional test case 4: "orange" - starts with 'o' (vowel)
    print("Test 4: 'orange' - should start with vowel")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # First character: 'o' = 0x6F
    dut.char_in.value = 0x6F
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "done should be high"
    assert dut.result.value == 1, f"Expected result=1 (vowel), got {dut.result.value}"
    print("  PASSED")
    
    # Additional test case 5: "Under" - starts with 'U' (vowel)
    print("Test 5: 'Under' - should start with vowel")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # First character: 'U' = 0x55
    dut.char_in.value = 0x55
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "done should be high"
    assert dut.result.value == 1, f"Expected result=1 (vowel), got {dut.result.value}"
    print("  PASSED")
    
    print("All 5 tests passed!")
