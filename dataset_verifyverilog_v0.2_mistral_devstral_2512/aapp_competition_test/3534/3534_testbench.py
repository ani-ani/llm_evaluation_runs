import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def compute_expected(num_notes, notes, K):
    """Simulate Mirka's playing and count correct notes"""
    if num_notes == 0:
        return 0
    
    played = [0] * num_notes
    played[0] = notes[0]
    correct = 1
    
    for i in range(1, num_notes):
        if notes[i] > notes[i-1]:
            played[i] = played[i-1] + K
        elif notes[i] < notes[i-1]:
            played[i] = played[i-1] - K
        else:
            played[i] = played[i-1]
        
        if played[i] == notes[i]:
            correct += 1
    
    return correct

def find_optimal_k(notes):
    """Find optimal K and max correct"""
    num_notes = len(notes)
    if num_notes == 0:
        return 0, 0
    
    # Generate candidate K values from adjacent differences
    candidates = {0}
    for i in range(num_notes - 1):
        diff = abs(notes[i+1] - notes[i])
        candidates.add(diff)
    
    best_k = 0
    max_correct = 0
    
    for K in candidates:
        correct = compute_expected(num_notes, notes, K)
        if correct > max_correct:
            max_correct = correct
            best_k = K
        elif correct == max_correct and K < best_k:
            best_k = K
    
    return max_correct, best_k

@cocotb.test()
async def test_mirka_optimizer(dut):
    """Test the Mirka optimizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.note_data.value = 0
    dut.note_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([1, 2, 0, 3, 1], 3, 2),
        ([2, 1, -6, -2, 1, 6, 10], 5, 4),
        ([5, 5, 5, 5], 4, 0),
        ([0, 10, 0, 10], 4, 10),
        ([1, 3, 5, 7], 4, 2),
        ([-5, -3, -1, -7], 3, 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for notes, expected_correct, expected_k in test_cases:
        print(f"
Testing with notes: {notes}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream in notes
        num_notes = len(notes)
        dut.note_valid.value = 1
        for i, note in enumerate(notes):
            dut.note_data.value = note & 0xFFFF
            if i == num_notes - 1:
                # After last note, wait for processing
                await RisingEdge(dut.clk)
                dut.note_valid.value = 0
            else:
                await RisingEdge(dut.clk)
        
        # Wait for computation to complete
        timeout = 500
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure("Timeout waiting for done signal")
        
        # Read results
        max_correct = int(dut.max_correct.value)
        best_k = int(dut.best_k.value)
        
        print(f"Expected: max_correct={expected_correct}, best_k={expected_k}")
        print(f"Got: max_correct={max_correct}, best_k={best_k}")
        
        if max_correct == expected_correct and best_k == expected_k:
            passed += 1
            print("PASS")
        else:
            print("FAIL")
            # Don't raise failure, just log
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")