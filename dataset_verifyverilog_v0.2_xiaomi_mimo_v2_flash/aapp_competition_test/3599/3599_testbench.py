import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_break_scheduler(dut):
    """Test the break scheduling algorithm"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 8 minutes, 3 musicians, each break 4 minutes
    # Expected: 0, 2, 4 (from example)
    dut.concert_length.value = 8
    dut.num_musicians.value = 3
    dut.break_durations[0].value = 4
    dut.break_durations[1].value = 4
    dut.break_durations[2].value = 4
    # Set unused entries
    for i in range(3, 8):
        dut.break_durations[i].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 100 cycles for)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not complete in time")
    
    if not dut.valid.value:
        raise TestFailure("Scheduling was marked invalid")
    
    # Check results
    actual = [int(dut.start_times[i].value) for i in range(3)]
    print(f"Test 1 - Expected: [0, 2, 4], Got: {actual}")
    
    # Verify schedule constraints
    # Create timeline to check overlaps
    timeline = [0] * 8
    for i in range(3):
        start = actual[i]
        dur = 4
        for t in range(start, start + dur):
            if t < 8:
                timeline[t] += 1
    
    # Check max overlaps
    max_overlap = max(timeline) if timeline else 0
    print(f"  Timeline overlaps: {timeline}")
    print(f"  Max concurrent: {max_overlap}")
    
    if max_overlap > 3:
        raise TestFailure(f"Too many concurrent breaks: {max_overlap} > 3")
    
    # Test Case 2: 10 minutes, 5 musicians, durations [7,5,1,2,3]
    # Expected from example: 3,3,9,0,0
    await Timer(100, units='ns')
    
    dut.concert_length.value = 10
    dut.num_musicians.value = 5
    dut.break_durations[0].value = 7
    dut.break_durations[1].value = 5
    dut.break_durations[2].value = 1
    dut.break_durations[3].value = 2
    dut.break_durations[4].value = 3
    # Set unused entries
    for i in range(5, 8):
        dut.break_durations[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not complete in time")
    
    if not dut.valid.value:
        raise TestFailure("Scheduling was marked invalid")
    
    actual2 = [int(dut.start_times[i].value) for i in range(5)]
    print(f"Test 2 - Expected: [3, 3, 9, 0, 0], Got: {actual2}")
    
    # Verify constraints
    timeline2 = [0] * 10
    durations2 = [7,5,1,2,3]
    for i in range(5):
        start = actual2[i]
        dur = durations2[i]
        for t in range(start, start + dur):
            if t < 10:
                timeline2[t] += 1
    
    max_overlap2 = max(timeline2) if timeline2 else 0
    print(f"  Timeline overlaps: {timeline2}")
    print(f"  Max concurrent: {max_overlap2}")
    
    if max_overlap2 > 3:
        raise TestFailure(f"Too many concurrent breaks: {max_overlap2} > 3")
    
    # Test Case 3: Small edge case
    await Timer(100, units='ns')
    
    dut.concert_length.value = 5
    dut.num_musicians.value = 2
    dut.break_durations[0].value = 2
    dut.break_durations[1].value = 2
    for i in range(2, 8):
        dut.break_durations[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    actual3 = [int(dut.start_times[i].value) for i in range(2)]
    print(f"Test 3 - Result: {actual3}")
    
    # Verify
    timeline3 = [0] * 5
    for i in range(2):
        start = actual3[i]
        dur = 2
        for t in range(start, start + dur):
            if t < 5:
                timeline3[t] += 1
    
    max_overlap3 = max(timeline3) if timeline3 else 0
    print(f"  Max concurrent: {max_overlap3}")
    
    if max_overlap3 > 3:
        raise TestFailure(f"Too many concurrent breaks: {max_overlap3} > 3")
    
    print("
All tests passed!")

# Additional utility test to verify the example outputs are valid
@cocotb.test()
async def test_examples_validity(dut):
    """Verify that provided example outputs satisfy constraints"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test example 1: T=8, N=3, durations [4,4,4], starts [0,2,4]
    starts1 = [0, 2, 4]
    durations1 = [4, 4, 4]
    
    # Build timeline
    timeline1 = [0] * 8
    for i in range(3):
        for t in range(starts1[i], starts1[i] + durations1[i]):
            timeline1[t] += 1
    
    max_overlap1 = max(timeline1)
    print(f"Example 1 timeline: {timeline1}, max overlap: {max_overlap1}")
    
    if max_overlap1 > 3:
        raise TestFailure("Example 1 violates constraint")
    
    # Test example 2: T=10, N=5, durations [7,5,1,2,3], starts [3,3,9,0,0]
    starts2 = [3, 3, 9, 0, 0]
    durations2 = [7, 5, 1, 2, 3]
    
    timeline2 = [0] * 10
    for i in range(5):
        for t in range(starts2[i], starts2[i] + durations2[i]):
            if t < 10:
                timeline2[t] += 1
    
    max_overlap2 = max(timeline2)
    print(f"Example 2 timeline: {timeline2}, max overlap: {max_overlap2}")
    
    if max_overlap2 > 3:
        raise TestFailure("Example 2 violates constraint")
    
    print("Example outputs are valid!")
