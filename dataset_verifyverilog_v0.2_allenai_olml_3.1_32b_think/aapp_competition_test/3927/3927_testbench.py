import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_weight_reveal_basic(dut):
    """Test basic functionality with n=4, values [1,4,2,2]"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load input: 4 weights [1, 4, 2, 2]
    dut.n_in.value = 4
    await RisingEdge(dut.clk)
    
    # Load values one by one
    values = [1, 4, 2, 2]
    for v in values:
        dut.value_in.value = v
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (allow 200 cycles max)
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 2 (either {2,2} or {1,4} can be uniquely identified)
    if dut.max_reveal.value != 2:
        raise TestFailure(f"Expected max_reveal=2, got {dut.max_reveal.value}")
    
    print("Test 1 passed: n=4, [1,4,2,2] -> max_reveal=2")

@cocotb.test()
async def test_weight_reveal_example2(dut):
    """Test second example: n=6, values [1,2,4,4,4,9]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 6
    await RisingEdge(dut.clk)
    
    values = [1, 2, 4, 4, 4, 9]
    for v in values:
        dut.value_in.value = v
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 2 (two 4's can be uniquely identified)
    if dut.max_reveal.value != 2:
        raise TestFailure(f"Expected max_reveal=2, got {dut.max_reveal.value}")
    
    print("Test 2 passed: n=6, [1,2,4,4,4,9] -> max_reveal=2")

@cocotb.test()
async def test_weight_reveal_all_same(dut):
    """Test with all identical weights: n=5, values [5,5,5,5,5]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 5
    await RisingEdge(dut.clk)
    
    for _ in range(5):
        dut.value_in.value = 5
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 5 (all same, can uniquely identify all)
    if dut.max_reveal.value != 5:
        raise TestFailure(f"Expected max_reveal=5, got {dut.max_reveal.value}")
    
    print("Test 3 passed: n=5, [5,5,5,5,5] -> max_reveal=5")

@cocotb.test()
async def test_weight_reveal_all_unique(dut):
    """Test with all distinct values: n=5, values [1,2,3,4,5]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 5
    await RisingEdge(dut.clk)
    
    values = [1, 2, 3, 4, 5]
    for v in values:
        dut.value_in.value = v
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 1 (can only guarantee one unique weight with single query)
    if dut.max_reveal.value != 1:
        raise TestFailure(f"Expected max_reveal=1, got {dut.max_reveal.value}")
    
    print("Test 4 passed: n=5, [1,2,3,4,5] -> max_reveal=1")

@cocotb.test()
async def test_weight_reveal_small_n(dut):
    """Test edge case: n=4, values [2,2,2,2]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 4
    await RisingEdge(dut.clk)
    
    for _ in range(4):
        dut.value_in.value = 2
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 4 (all same, can uniquely identify all)
    if dut.max_reveal.value != 4:
        raise TestFailure(f"Expected max_reveal=4, got {dut.max_reveal.value}")
    
    print("Test 5 passed: n=4, [2,2,2,2] -> max_reveal=4")

@cocotb.test()
async def test_weight_reveal_three_pairs(dut):
    """Test n=6, values [1,1,2,2,3,3] - three pairs"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 6
    await RisingEdge(dut.clk)
    
    values = [1, 1, 2, 2, 3, 3]
    for v in values:
        dut.value_in.value = v
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 2 (can identify one pair)
    if dut.max_reveal.value != 2:
        raise TestFailure(f"Expected max_reveal=2, got {dut.max_reveal.value}")
    
    print("Test 6 passed: n=6, [1,1,2,2,3,3] -> max_reveal=2")

@cocotb.test()
async def test_weight_reveal_large_count(dut):
    """Test with many same values: n=8, values [5,5,5,5,5,5,5,5]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 8
    await RisingEdge(dut.clk)
    
    for _ in range(8):
        dut.value_in.value = 5
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 8
    if dut.max_reveal.value != 8:
        raise TestFailure(f"Expected max_reveal=8, got {dut.max_reveal.value}")
    
    print("Test 7 passed: n=8, [5,5,5,5,5,5,5,5] -> max_reveal=8")

@cocotb.test()
async def test_weight_reveal_mixed_counts(dut):
    """Test n=7, values [1,1,1,2,2,3,3]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 7
    await RisingEdge(dut.clk)
    
    values = [1, 1, 1, 2, 2, 3, 3]
    for v in values:
        dut.value_in.value = v
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 3 (three 1's can be uniquely queried as sum=3, k=3)
    if dut.max_reveal.value != 3:
        raise TestFailure(f"Expected max_reveal=3, got {dut.max_reveal.value}")
    
    print("Test 8 passed: n=7, [1,1,1,2,2,3,3] -> max_reveal=3")

@cocotb.test()
async def test_weight_reveal_nine_items(dut):
    """Test n=9, values [2,2,2,2,2,4,4,4,4] - two groups"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 9
    await RisingEdge(dut.clk)
    
    values = [2, 2, 2, 2, 2, 4, 4, 4, 4]
    for v in values:
        dut.value_in.value = v
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 5 (five 2's) or 4 (four 4's)
    if dut.max_reveal.value != 5 and dut.max_reveal.value != 4:
        raise TestFailure(f"Expected max_reveal=4 or 5, got {dut.max_reveal.value}")
    
    print(f"Test 9 passed: n=9, [2,2,2,2,2,4,4,4,4] -> max_reveal={dut.max_reveal.value}")

@cocotb.test()
async def test_weight_reveal_n=10_max(dut):
    """Test n=10 max size: values [1,1,1,1,1,1,1,1,1,1]"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.input_valid.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 10
    await RisingEdge(dut.clk)
    
    for _ in range(10):
        dut.value_in.value = 1
        dut.input_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.input_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Module did not complete in time")
    
    # Expected: 10
    if dut.max_reveal.value != 10:
        raise TestFailure(f"Expected max_reveal=10, got {dut.max_reveal.value}")
    
    print("Test 10 passed: n=10, [1,1,1,1,1,1,1,1,1,1] -> max_reveal=10")