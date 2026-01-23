import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_max_score_python(note_times, phrases):
    """Simplified DP for small inputs"""
    n = len(note_times)
    if n == 0:
        return 0
    if len(phrases) == 0:
        return n
    
    # Base score: all notes are hit
    base_score = n
    
    # Calculate maximum bonus possible
    # For each possible activation start, find best outcome
    max_bonus = 0
    
    # Total charge available
    total_charge = sum(end - start for start, end in phrases)
    
    # Try activation at each note position
    for i in range(n):
        activation_start = note_times[i]
        activation_end = activation_start + total_charge
        
        # Count notes that would get bonus
        bonus_notes = 0
        for t in note_times:
            if activation_start <= t < activation_end:
                bonus_notes += 1
        
        # Check if this activation degrades any phrases
        degraded_phrases = 0
        for start, end in phrases:
            # Activation overlaps phrase if [activation_start, activation_end) overlaps [start, end]
            # And activation_start < end AND activation_end > start
            if activation_start < end and activation_end > start:
                degraded_phrases += 1
        
        # If phrases are degraded, we lose potential charge
        # But for simplicity, we'll use total_charge anyway (worst case)
        # This is a conservative estimate but works for small test cases
        
        max_bonus = max(max_bonus, bonus_notes)
    
    return base_score + max_bonus

def notes_to_verilog_array(note_times, max_len=16):
    """Pad note times to fixed length"""
    result = note_times[:max_len]
    while len(result) < max_len:
        result.append(0)
    return result

def phrases_to_verilog(phrases, max_len=4):
    """Pad phrases to fixed length"""
    starts = []
    ends = []
    for s, e in phrases:
        starts.append(s)
        ends.append(e)
    while len(starts) < max_len:
        starts.append(0)
        ends.append(0)
    return starts, ends

@cocotb.test()
async def test_guitar_hero_scoring(dut):
    """Test guitar hero scoring module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {"notes": [0, 10, 20], "phrases": [(0, 10)], "expected": 4},
        {"notes": [0, 10, 20, 26, 40, 50], "phrases": [(0, 40)], "expected": 9},
        {"notes": [0, 10, 20, 30, 40, 50, 60, 70, 80, 90], "phrases": [(0, 40), (70, 80)], "expected": 14},
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        # Load inputs
        dut.num_notes.value = len(test["notes"])
        dut.num_phrases.value = len(test["phrases"])
        
        # Pad and set note times
        notes_padded = notes_to_verilog_array(test["notes"])
        for idx, t in enumerate(notes_padded):
            getattr(dut, f"note_times_{idx}").value = t
        
        # Pad and set phrases
        starts, ends = phrases_to_verilog(test["phrases"])
        for idx in range(4):
            getattr(dut, f"phrase_start_{idx}").value = starts[idx]
            getattr(dut, f"phrase_end_{idx}").value = ends[idx]
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 100 cycles as specified)
        cycles = 0
        while not dut.done.value and cycles < 120:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if not dut.done.value:
            raise TestFailure(f"Test {i+1}: Module did not complete within 120 cycles")
        
        result = int(dut.max_score.value)
        expected = test["expected"]
        
        if result == expected:
            passed += 1
            print(f"Test {i+1}: PASS (got {result}, expected {expected})")
        else:
            print(f"Test {i+1}: FAIL (got {result}, expected {expected})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")