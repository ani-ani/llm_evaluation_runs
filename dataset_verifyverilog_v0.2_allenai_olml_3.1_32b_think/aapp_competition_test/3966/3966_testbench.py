import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def sort_and_calculate(numbers):
    n = len(numbers)
    if n == 1:
        return numbers[0]
    sorted_nums = sorted(numbers)
    s = 0
    for i in range(n):
        s += sorted_nums[i] * (i + 2)
    return s - sorted_nums[-1]

@cocotb.test()
async def test_score_calculator(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Example from prompt (3, 1, 5)
    # We fill array with 0s for unused indices, assuming module handles unused entries gracefully (e.g. ignored in calc if we had a valid bit)
    # However, the prompt implies fixed size N=8. Let's assume inputs are padded or the module waits for 'N' inputs.
    # To keep it simple, we will input 3 numbers and assume the module knows N=3 (or we need to tell it).
    # Let's patch the spec: The module will assume N=3 for the test, but let's verify the logic.
    # Actually, let's simulate the process: Input [3, 1, 5].
    # But wait, the module in the prompt takes N=8. We need to input 8 values.
    # Let's define inputs for a size 3 test, but map them to the first 3 slots.
    # Wait, the prompt implies N=8. Let's re-read: "Scale inputs down dramatically".
    # Let's modify the test to reflect a realistic implementation for N=8, but we only use 3 slots in the first test.
    # ASSUMPTION: The module calculates for ALL 8 slots. We must fill them.
    # Let's test with 3 numbers: [3, 1, 5] and 5 zeros.
    # Wait, zeros might affect the result (0*weight adds nothing, but weight increments).
    # IF the module calculates for N=8 fixed:
    # Input: 3, 1, 5, 0, 0, 0, 0, 0.
    # Sorted: 0, 0, 0, 0, 0, 1, 3, 5
    # Weights: 2, 3, 4, 5, 6, 7, 8, 9
    # Sum = 0*2 + ... + 1*7 + 3*8 + 5*9 = 7 + 24 + 45 = 76.
    # Result = 76 - 5 = 71.
    # But the problem asks for 'n' inputs. 
    # STRATEGY: I will adapt the testbench to treat the module as having a 'load' phase.
    # Since the prompt asks for fixed N=8, I will test with 3 non-zero values and 5 zeros.
    
    test_inputs = [3, 1, 5, 0, 0, 0, 0, 0]
    dut._log.info("Test Case 1: Inputs {}").format(test_inputs))
    
    # Load inputs
    for i in range(8):
        dut.data_in.value = test_inputs[i]
        dut.index_in.value = i
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    cycles = 0
    while dut.done.value == 0 and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1

    if cycles >= 500:
        raise TestFailure("Timeout: Done signal not asserted")

    # Check result
    expected = sort_and_calculate(test_inputs)
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: Expected {expected}, Got {dut.result.value}")
    
    dut._log.info(f"Test 1 Passed: {dut.result.value}")

    # Test Case 2: Single number
    # Input: [10] + zeros
    test_inputs = [10] + [0]*7
    dut._log.info("Test Case 2: Inputs {}").format(test_inputs))
    
    # Reset logic or just re-load? Let's assume we need to reset to IDLE or the module supports re-trigger.
    # To be safe, we can do a mini reset or just assume the module loops back.
    # Let's force a quick reset for cleanliness
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i in range(8):
        dut.data_in.value = test_inputs[i]
        dut.index_in.value = i
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    while dut.done.value == 0 and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1

    expected = sort_and_calculate(test_inputs)
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: Expected {expected}, Got {dut.result.value}")
    
    dut._log.info(f"Test 2 Passed: {dut.result.value}")

    # Test Case 3: Randomized
    test_inputs = sorted([random.randint(1, 20) for _ in range(8)]) # Random, sorted doesn't matter for result check but helps thinking
    # Actually let's use unsorted input to test sort
    test_inputs = [random.randint(1, 20) for _ in range(8)]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for i in range(8):
        dut.data_in.value = test_inputs[i]
        dut.index_in.value = i
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles = 0
    while dut.done.value == 0 and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1

    expected = sort_and_calculate(test_inputs)
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: Expected {expected}, Got {dut.result.value}")
    
    dut._log.info(f"Test 3 Passed: {dut.result.value}")
