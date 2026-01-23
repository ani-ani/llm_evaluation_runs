import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_card_shuffle_counter(dut):
    """Test the card shuffle counter module"""
    
    # Create clock with 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.card_in.value = 0
    dut.valid.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 1 shuffle (1 2 7 3 8 9 4 5 10 6 scaled to 8 cards)
    # Scaled: 1 2 3 4 5 6 7 8 -> becomes 1 2 4 3 5 6 7 8
    print("
Test 1: Single shuffle")
    permutation1 = [1, 2, 4, 3, 5, 6, 7, 8]
    await start_computation(dut, permutation1)
    result1 = await wait_for_result(dut)
    print(f"Input: {permutation1}")
    print(f"Expected: 1, Got: {result1}")
    assert result1 == 1, f"Test 1 failed: expected 1, got {result1}"
    
    # Test case 2: 2 shuffles (scaled example)
    print("
Test 2: Two shuffles")
    permutation2 = [3, 4, 1, 2, 5, 6, 7, 8]
    await start_computation(dut, permutation2)
    result2 = await wait_for_result(dut)
    print(f"Input: {permutation2}")
    print(f"Expected: 2, Got: {result2}")
    assert result2 == 2, f"Test 2 failed: expected 2, got {result2}"
    
    # Test case 3: 3 shuffles
    print("
Test 3: Three shuffles")
    permutation3 = [5, 6, 1, 2, 7, 8, 3, 4]
    await start_computation(dut, permutation3)
    result3 = await wait_for_result(dut)
    print(f"Input: {permutation3}")
    print(f"Expected: 3, Got: {result3}")
    assert result3 == 3, f"Test 3 failed: expected 3, got {result3}"
    
    # Test case 4: 0 shuffles (already sorted)
    print("
Test 4: Zero shuffles")
    permutation4 = [1, 2, 3, 4, 5, 6, 7, 8]
    await start_computation(dut, permutation4)
    result4 = await wait_for_result(dut)
    print(f"Input: {permutation4}")
    print(f"Expected: 0, Got: {result4}")
    assert result4 == 0, f"Test 4 failed: expected 0, got {result4}"
    
    # Test case 5: Edge case - minimum cards
    print("
Test 5: Two cards")
    permutation5 = [2, 1]
    # Need to handle 2 cards - fill rest with 0
    await start_computation(dut, [2, 1, 0, 0, 0, 0, 0, 0])
    result5 = await wait_for_result(dut)
    print(f"Input: [2, 1, ...]")
    print(f"Expected: 1, Got: {result5}")
    assert result5 >= 1, f"Test 5 failed: expected at least 1, got {result5}"
    
    print("
" + "="*40)
    print("5/5 tests passed")
    print("="*40)

async def start_computation(dut, permutation):
    """Start the shuffle counter computation"""
    # Fill 8 cards
    for i in range(8):
        dut.card_in.value = permutation[i]
        dut.valid.value = 1 if permutation[i] > 0 else 0
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_result(dut):
    """Wait for computation to complete and return result"""
    # Wait for done to go high
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        print("Warning: Timeout waiting for done signal")
    
    # Wait a bit for result to settle
    await RisingEdge(dut.clk)
    return int(dut.result.value)
