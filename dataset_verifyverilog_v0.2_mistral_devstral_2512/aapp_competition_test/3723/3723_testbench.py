import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_pokemon_gcd(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.pokemon_strength[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Input [2, 3, 4] -> Expected: 2 (Factors: 2 appears twice)
    # Scaled: n=3, values [2, 3, 4]
    dut.n.value = 3
    dut.pokemon_strength[0].value = 2
    dut.pokemon_strength[1].value = 3
    dut.pokemon_strength[2].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 40 cycles to be safe)
    for _ in range(40):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.result.value == 2, f"Test 1 Failed: Expected 2, got {dut.result.value}"
    print("Test 1 Passed: [2,3,4] -> 2")

    # Test Case 2: Input [2, 3, 4, 6, 7] -> Expected: 3 (Factors: 2 appears 3 times)
    # Scaled: n=5, values [2, 3, 4, 6, 7]
    dut.n.value = 5
    dut.pokemon_strength[0].value = 2
    dut.pokemon_strength[1].value = 3
    dut.pokemon_strength[2].value = 4
    dut.pokemon_strength[3].value = 6
    dut.pokemon_strength[4].value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(40):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 3, f"Test 2 Failed: Expected 3, got {dut.result.value}"
    print("Test 2 Passed: [2,3,4,6,7] -> 3")

    # Test Case 3: Input [5, 6, 4] -> Expected: 2 (Factors: 2 appears 2 times)
    # Scaled: n=3, values [5, 6, 4]
    dut.n.value = 3
    dut.pokemon_strength[0].value = 5
    dut.pokemon_strength[1].value = 6
    dut.pokemon_strength[2].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(40):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 2, f"Test 3 Failed: Expected 2, got {dut.result.value}"
    print("Test 3 Passed: [5,6,4] -> 2")

    # Test Case 4: Input [9, 4, 2, 3, 3, 9, 8] -> Expected: 4 (Factors: 2 or 3 appears 4 times)
    # Scaled: n=7
    dut.n.value = 7
    dut.pokemon_strength[0].value = 9
    dut.pokemon_strength[1].value = 4
    dut.pokemon_strength[2].value = 2
    dut.pokemon_strength[3].value = 3
    dut.pokemon_strength[4].value = 3
    dut.pokemon_strength[5].value = 9
    dut.pokemon_strength[6].value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 4, f"Test 4 Failed: Expected 4, got {dut.result.value}"
    print("Test 4 Passed: [9,4,2,3,3,9,8] -> 4")

    # Test Case 5: Input [1, 1, 1, 1, 1, 1, 1, 1] -> Expected: 1 (No common factor > 1, so result is 1)
    # Scaled: n=8, values all 1s
    dut.n.value = 8
    for i in range(8):
        dut.pokemon_strength[i].value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(50):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.result.value == 1, f"Test 5 Failed: Expected 1, got {dut.result.value}"
    print("Test 5 Passed: [1,1,...] -> 1")

    print(f"All tests passed!")
