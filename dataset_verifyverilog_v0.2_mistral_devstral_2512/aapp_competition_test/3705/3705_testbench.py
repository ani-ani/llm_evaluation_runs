import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_phone_numbers(dut):
    """Test the phone_numbers module with various inputs"""
    
    # Create a 10MHz clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.digit_vector.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(digit_vector, expected_result):
        dut.digit_vector.value = digit_vector
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 120 cycles + safety margin)
        for _ in range(150):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        assert dut.done.value == 1, "Done signal not asserted"
        assert dut.result.value == expected_result, f"Expected {expected_result}, got {dut.result.value}"
        print(f"Test passed: Vector {digit_vector} -> Result {dut.result.value}")

    # Test cases scaled for 100-bit input
    # Case 1: 11 cards, 1 '8' -> Result: 1
    # 00000000008 -> bit 8 set
    await run_test(1 << 8, 1)
    
    # Case 2: 22 cards, 2 '8's -> Result: 2
    # 0011223344556677889988 -> 2 of each digit 0-9
    # Bit 8 is set twice. Total cards 22. 22/11=2.
    # Bit vector: 2 bits for each digit 0-9 -> 0x3FF (bits 0-9 set)
    await run_test(0x3FF, 2)
    
    # Case 3: 11 cards, 0 '8's -> Result: 0
    # 31415926535 -> 1,3,4,5,9,2,6 (no 8)
    # Bits set: 1,2,3,4,5,6,9
    vec = (1<<1) | (1<<2) | (1<<3) | (1<<4) | (1<<5) | (1<<6) | (1<<9)
    await run_test(vec, 0)
    
    # Case 4: All 100 cards are '8's
    # 100/11 = 9. Count '8' = 100. Min = 9.
    vec = 0
    for i in range(100):
        vec |= (1 << i) # We will fix this: it needs 100 '8's, so bits 0-99 must be 1
    # Actually, the input string of 100 chars '8' means 100 cards of digit 8.
    # The vector represents availability of digits. 
    # If we have 100 '8's, the vector must represent that count.
    # However, the prompt says "bit i is 1 if digit i is present".
    # This implies boolean presence. To represent "100 eights", we need 100 bits set at index 8?
    # Wait, the input is a string of digits. 
    # Let's stick to the interpretation: digit_vector is a bitmask of available cards.
    # For test case 4: 100 eights. We need 100 bits set at position 8?
    # That exceeds 1 bit width. 
    # Correction: The prompt says "input [99:0] digit_vector // 100-bit vector where bit i is 1 if digit i is present".
    # This is likely a misunderstanding of the format. 
    # Let's assume `digit_vector` is a 100-bit vector where each bit represents a card.
    # Bit i = 1 if the i-th card is an '8'. Bit i = 0 if it's any other digit.
    # This maps 100 cards to 100 bits.
    
    # Revised Test Cases for the logic:
    # 1. Vector: 1 bit set (one '8') -> Count '8'=1, Total=1 -> Result 0 (1/11=0)
    # 2. Vector: 11 bits set -> Count '8'=11, Total=11 -> Result 1
    # 3. Vector: 22 bits set -> Count '8'=22, Total=22 -> Result 2
    # 4. Vector: 0 bits set -> Result 0
    # 5. Vector: 100 bits set -> Count '8'=100, Total=100 -> Result 9 (100/11=9)
    
    print("Running adjusted tests...")
    
    # Test 1: 1 '8', 1 total card
    await RisingEdge(dut.clk)
    dut.digit_vector.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value: break
    assert dut.result.value == 0
    
    # Test 2: 11 '8's
    val = (1 << 11) - 1
    await RisingEdge(dut.clk)
    dut.digit_vector.value = val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value: break
    assert dut.result.value == 1
    
    # Test 3: 22 '8's
    val = (1 << 22) - 1
    await RisingEdge(dut.clk)
    dut.digit_vector.value = val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value: break
    assert dut.result.value == 2
    
    # Test 4: 100 '8's (all bits high)
    val = (1 << 100) - 1
    await RisingEdge(dut.clk)
    dut.digit_vector.value = val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value: break
    assert dut.result.value == 9
    
    print("All tests passed!")
