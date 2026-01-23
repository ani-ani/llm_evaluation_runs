import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_dice_reroll_optimizer(dut):
    """Test dice re-roll optimizer with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases scaled down for K <= 8
    test_cases = [
        # Case 1: 3 dice, target 9, rolls [5,4,1] -> keep best, reroll 1
        {
            'K': 3,
            'target': 9,
            'rolls': [5, 4, 1],
            'expected': 1
        },
        # Case 2: 4 dice, target 13, rolls [2,2,2,2] -> need more sum, reroll 3  
        {
            'K': 4,
            'target': 13,
            'rolls': [2, 2, 2, 2],
            'expected': 3
        },
        # Case 3: Smaller version - 6 dice, target 21, perfect sequence -> reroll 0
        {
            'K': 6,
            'target': 21,
            'rolls': [1, 2, 3, 4, 5, 6],
            'expected': 0
        },
        # Case 4: 4 dice, target 14, rolls [1,1,1,6] -> reroll 3 small ones
        {
            'K': 4,
            'target': 14,
            'rolls': [1, 1, 1, 6],
            'expected': 3
        },
        # Case 5: 5 dice, target 20, rolls [3,4,5,5,3] -> already close, maybe keep all
        {
            'K': 5,
            'target': 20,
            'rolls': [3, 4, 5, 5, 3],
            'expected': 0
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"
Test case {i+1}: K={tc['K']}, T={tc['target']}, rolls={tc['rolls']}")
        
        # Set inputs
        dut.K.value = tc['K']
        dut.target.value = tc['target']
        for j in range(tc['K']):
            dut.initial_rolls[j].value = tc['rolls'][j]
        # Initialize unused entries
        for j in range(tc['K'], 8):
            dut.initial_rolls[j].value = 0
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 200
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  TIMEOUT: done signal not asserted after {timeout} cycles")
            continue
        
        result = int(dut.optimal_k.value)
        expected = tc['expected']
        
        print(f"  Result: {result}, Expected: {expected}")
        
        if result == expected:
            passed += 1
            print("  PASS")
        else:
            print(f"  FAIL: Expected {expected}, got {result}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
}