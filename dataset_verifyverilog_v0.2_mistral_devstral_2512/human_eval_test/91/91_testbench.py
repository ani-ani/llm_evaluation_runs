import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_boredom_counter(dut):
    """Test boredom counter with various string patterns"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_data.value = 0
    dut.char_index.value = 0
    await Timer(50, units='ns')
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def send_string(s):
        """Helper to send string to DUT one char per cycle"""
        # Pad to 16 characters
        padded = s.ljust(16, ' ')
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send each character
        for i in range(16):
            dut.char_data.value = ord(padded[i])
            dut.char_index.value = i
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        return dut.boredom_count.value
    
    # Test 1: "Hello world" -> 0
    result = await send_string("Hello world")
    if result != 0:
        raise TestFailure(f"Test 1 failed: expected 0, got {result}")
    print(f"Test 1: 'Hello world' -> {result} (PASS)")
    
    # Test 2: "Is the sky blue?" -> 0
    result = await send_string("Is the sky blue?")
    if result != 0:
        raise TestFailure(f"Test 2 failed: expected 0, got {result}")
    print(f"Test 2: 'Is the sky blue?' -> {result} (PASS)")
    
    # Test 3: "I love It !" -> 1
    result = await send_string("I love It !")
    if result != 1:
        raise TestFailure(f"Test 3 failed: expected 1, got {result}")
    print(f"Test 3: 'I love It !' -> {result} (PASS)")
    
    # Test 4: "bIt" -> 0
    result = await send_string("bIt")
    if result != 0:
        raise TestFailure(f"Test 4 failed: expected 0, got {result}")
    print(f"Test 4: 'bIt' -> {result} (PASS)")
    
    # Test 5: "I feel good today. I will be productive. will kill It" -> 2
    # This string is longer than 16 chars, need to test with shorter version
    # Original: "I feel good today. I will be productive. will kill It"
    # Let's use "I love. I work. end" which should give 2
    result = await send_string("I love. I work. end")
    if result != 2:
        raise TestFailure(f"Test 5 failed: expected 2, got {result}")
    print(f"Test 5: 'I love. I work. end' -> {result} (PASS)")
    
    # Test 6: "You and I are going" -> 0
    result = await send_string("You and I are going")
    if result != 0:
        raise TestFailure(f"Test 6 failed: expected 0, got {result}")
    print(f"Test 6: 'You and I are going' -> {result} (PASS)")
    
    # Edge case: Only "I" -> 1
    result = await send_string("I")
    if result != 1:
        raise TestFailure(f"Edge case 'I' failed: expected 1, got {result}")
    print(f"Edge case: 'I' -> {result} (PASS)")
    
    # Edge case: Multiple spaces "I   love" -> 1
    result = await send_string("I   love")
    if result != 1:
        raise TestFailure(f"Edge case spaces failed: expected 1, got {result}")
    print(f"Edge case: 'I   love' -> {result} (PASS)")
    
    # Edge case: Delimiter at end "I love!" -> 1
    result = await send_string("I love!")
    if result != 1:
        raise TestFailure(f"Edge case delimiter end failed: expected 1, got {result}")
    print(f"Edge case: 'I love!' -> {result} (PASS)")
    
    print("All tests passed!")
