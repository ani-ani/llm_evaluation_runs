import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_hr_optimization(dut):
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.last_day.value = 0
    dut.hire_count.value = 0
    dut.fire_count.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to feed a day
    async def feed_day(hire, fire, is_last):
        dut.hire_count.value = hire
        dut.fire_count.value = fire
        dut.valid_in.value = 1
        dut.last_day.value = 1 if is_last else 0
        await RisingEdge(dut.clk)
        # Wait until valid_out goes high to confirm acceptance (optional, depends on design)
        # Here we assume design consumes input immediately in READ_DAY state
        dut.valid_in.value = 0
        # Wait for output
        while dut.valid_out.value == 0:
            await RisingEdge(dut.clk)
        hr_id = int(dut.hr_id_out.value)
        day = int(dut.day_index_out.value)
        return hr_id, day

    # Test Case 1: Example 1 (Scaled down)
    # Original: 4 days: (0,3), (1,1), (2,1), (2,0)
    # Adapted: Same counts fit in 8 bits.
    # Expected logic:
    # Day 1: Hire 3, Fire 0. Stack: [ID1, ID1, ID1]. Assign ID 1. Output 1.
    # Day 2: Hire 1, Fire 1. Fire pops ID 1. Must pick ID != 1. Pick ID 2. Push ID 2. Stack: [ID1, ID1, ID2]. Output 2.
    # Day 3: Hire 1, Fire 2. Fire pops ID 2, ID 1. Fired IDs: {1, 2}. Must pick ID != 1 and != 2. Pick ID 3. Push ID 3. Stack: [ID1, ID3]. Output 3.
    # Day 4: Hire 0, Fire 2. Fire pops ID 3, ID 1. Fired IDs: {1, 3}. Must pick ID != 1 and != 3. Can pick ID 2 (since ID 2 is not in fired set). Push nothing. Stack: empty. Output 2.
    # Min HR count should be 3.
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Day 1
    hr, day = await feed_day(3, 0, False)
    assert hr == 1 and day == 0, f"Day 1 failed: got {hr}, {day}"
    
    # Day 2
    hr, day = await feed_day(1, 1, False)
    assert hr == 2 and day == 1, f"Day 2 failed: got {hr}, {day}"

    # Day 3
    hr, day = await feed_day(1, 2, False)
    assert hr == 3 and day == 2, f"Day 3 failed: got {hr}, {day}"

    # Day 4
    hr, day = await feed_day(0, 2, True)
    assert hr == 2 and day == 3, f"Day 4 failed: got {hr}, {day}"

    # Check done
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done signal not set"
    min_hr = int(dut.min_hr_count.value)
    assert min_hr == 3, f"Min HR count failed: got {min_hr}, expected 3"

    print("Test Case 1 Passed")

    # Reset for Test Case 2
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Example 2 (Scaled down)
    # Original: 6 days: (0,10), (0,5), (2,0), (0,0), (0,100), (50,100)
    # Scaled: Reduce counts to fit 8 days/64 workers.
    # Let's use: (0,5), (0,3), (1,0), (0,0), (0,5), (3,5)
    # Expected logic:
    # Day 1: Hire 5. Assign ID 1. Stack: 5xID1.
    # Day 2: Hire 3. Assign ID 1 (same as stack). Stack: 8xID1.
    # Day 3: Fire 1. Stack: 7xID1. Fired ID 1. Need ID != 1. Assign ID 2. Push 0. Stack: 7xID1.
    # Day 4: Nothing. Assign ID 2 (last used). Stack: 7xID1.
    # Day 5: Hire 5. Need ID != 1 (stack top is 1). ID 2 works. Stack: 7xID1, 5xID2.
    # Day 6: Fire 3, Hire 5. Fire 3xID2. Fired set {2}. Need ID != 2. ID 1 works (and is available in stack? No, stack top is ID2? Wait, stack is 7xID1 then 5xID2. Top is ID2. Fired 3 ID2s. New top is ID1? No, wait. Stack after day 5: [ID1x7, ID2x5]. Firing 3 pops ID2, ID2, ID2. Top is still ID2? No, pops 3. Stack: [ID1x7, ID2x2]. Fired set {2}. Hires: 5. Need ID != 2. ID 1 works. Push 5xID1. Stack: [ID1x7, ID2x2, ID1x5]. Min HR count = 2.
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Day 1
    hr, day = await feed_day(5, 0, False)
    assert hr == 1 and day == 0
    # Day 2
    hr, day = await feed_day(3, 0, False)
    assert hr == 1 and day == 1
    # Day 3
    hr, day = await feed_day(0, 1, False)
    assert hr == 2 and day == 2
    # Day 4
    hr, day = await feed_day(0, 0, False)
    assert hr == 2 and day == 3
    # Day 5
    hr, day = await feed_day(5, 0, False)
    assert hr == 2 and day == 4
    # Day 6
    hr, day = await feed_day(5, 3, True)
    assert hr == 1 and day == 5

    await RisingEdge(dut.clk)
    assert dut.done.value == 1
    min_hr = int(dut.min_hr_count.value)
    assert min_hr == 2, f"Min HR count failed: got {min_hr}, expected 2"

    print("Test Case 2 Passed")
    print("All tests passed!")