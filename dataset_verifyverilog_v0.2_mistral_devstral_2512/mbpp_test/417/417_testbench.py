import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def int_to_bits(val, width):
    """Convert integer to binary string for debugging"""
    return bin(val)[2:].zfill(width)

def pack_tuple(first, second):
    """Pack tuple values into a single integer for comparison"""
    return (first << 2) | second

@cocotb.test()
async def test_tuple_grouping_basic(dut):
    """Test basic tuple grouping functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.tuple_first.value = 0
    dut.tuple_second.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [('x','y'), ('x','z'), ('w','t')] -> grouped
    # Map: x=0, y=1, z=2, w=3, t=0
    dut.tuple_first.value = 0  # x, x, w, unused
    dut.tuple_second.value = 0  # Initialize all
    
    # Write inputs
    for i in range(4):
        dut.tuple_first[i].value = 0
        dut.tuple_second[i].value = 0
    
    dut.tuple_first[0].value = 0  # x
    dut.tuple_second[0].value = 1  # y
    dut.tuple_first[1].value = 0  # x
    dut.tuple_second[1].value = 2  # z
    dut.tuple_first[2].value = 3  # w
    dut.tuple_second[2].value = 0  # t
    dut.tuple_first[3].value = 0  # unused
    dut.tuple_second[3].value = 0  # unused
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check results
    if not dut.done.value:
        raise TestFailure("Done signal not asserted within 15 cycles")
    
    assert dut.num_groups.value == 2, f"Expected 2 groups, got {dut.num_groups.value}"
    
    # Verify group 1 (key=x=0)
    assert dut.group_first[0].value == 0, f"Group 0 key should be 0, got {dut.group_first[0].value}"
    assert dut.group_size[0].value == 2, f"Group 0 size should be 2, got {dut.group_size[0].value}"
    assert dut.group_data[0].value == 1, f"Group 0[0] should be 1, got {dut.group_data[0].value}"
    assert dut.group_data[1].value == 2, f"Group 0[1] should be 2, got {dut.group_data[1].value}"
    
    # Verify group 2 (key=w=3)
    assert dut.group_first[1].value == 3, f"Group 1 key should be 3, got {dut.group_first[1].value}"
    assert dut.group_size[1].value == 1, f"Group 1 size should be 1, got {dut.group_size[1].value}"
    assert dut.group_data[2].value == 0, f"Group 1[0] should be 0, got {dut.group_data[2].value}"
    
    print(f"Test 1 passed: Found {dut.num_groups.value} groups, grouped correctly")

@cocotb.test()
async def test_tuple_grouping_all_same(dut):
    """Test grouping when all first elements are same"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: [('a','b'), ('a','c'), ('d','e')] where a=0, b=1, c=2, d=3, e=0
    for i in range(4):
        dut.tuple_first[i].value = 0
        dut.tuple_second[i].value = 0
    
    dut.tuple_first[0].value = 0  # a
    dut.tuple_second[0].value = 1  # b
    dut.tuple_first[1].value = 0  # a
    dut.tuple_second[1].value = 2  # c
    dut.tuple_first[2].value = 3  # d
    dut.tuple_second[2].value = 0  # e
    dut.tuple_first[3].value = 0
    dut.tuple_second[3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value, "Done not asserted"
    assert dut.num_groups.value == 2
    assert dut.group_first[0].value == 0
    assert dut.group_size[0].value == 2
    assert dut.group_data[0].value == 1
    assert dut.group_data[1].value == 2
    assert dut.group_first[1].value == 3
    assert dut.group_size[1].value == 1
    assert dut.group_data[2].value == 0
    
    print(f"Test 2 passed: All-same grouping works")

@cocotb.test()
async def test_tuple_grouping_duplicates(dut):
    """Test grouping with duplicate tuples"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: [('f','g'), ('f','g'), ('h','i')] where f=0, g=1, h=3, i=2
    for i in range(4):
        dut.tuple_first[i].value = 0
        dut.tuple_second[i].value = 0
    
    dut.tuple_first[0].value = 0  # f
    dut.tuple_second[0].value = 1  # g
    dut.tuple_first[1].value = 0  # f
    dut.tuple_second[1].value = 1  # g (duplicate)
    dut.tuple_first[2].value = 3  # h
    dut.tuple_second[2].value = 2  # i
    dut.tuple_first[3].value = 0
    dut.tuple_second[3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value, "Done not asserted"
    assert dut.num_groups.value == 2
    assert dut.group_first[0].value == 0
    assert dut.group_size[0].value == 2  # Both duplicates included
    assert dut.group_data[0].value == 1
    assert dut.group_data[1].value == 1
    assert dut.group_first[1].value == 3
    assert dut.group_size[1].value == 1
    assert dut.group_data[2].value == 2
    
    print(f"Test 3 passed: Duplicates handled correctly")

@cocotb.test()
async def test_tuple_grouping_all_different(dut):
    """Test when all tuples have different first elements"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # All different: [(0,1), (1,2), (2,3), (3,0)]
    for i in range(4):
        dut.tuple_first[i].value = i
        dut.tuple_second[i].value = (i + 1) % 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value, "Done not asserted"
    assert dut.num_groups.value == 4
    for i in range(4):
        assert dut.group_first[i].value == i
        assert dut.group_size[i].value == 1
        assert dut.group_data[i].value == (i + 1) % 4
    
    print(f"Test 4 passed: All-different grouping works")

@cocotb.test()
async def test_tuple_grouping_single_tuple(dut):
    """Test with single tuple only"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single: [(2,3)]
    for i in range(4):
        dut.tuple_first[i].value = 0
        dut.tuple_second[i].value = 0
    
    dut.tuple_first[0].value = 2
    dut.tuple_second[0].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value, "Done not asserted"
    assert dut.num_groups.value == 1
    assert dut.group_first[0].value == 2
    assert dut.group_size[0].value == 1
    assert dut.group_data[0].value == 3
    
    print(f"Test 5 passed: Single tuple works")

print("All tests defined. Run with: pytest -vs")