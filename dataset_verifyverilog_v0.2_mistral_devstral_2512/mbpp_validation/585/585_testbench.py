import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def to_fixed_point(value):
    """Convert float to Q16.16 fixed-point integer"""
    return int(value * 65536)

@cocotb.test()
async def test_top_items_finder_basic(dut):
    """Test finding top 1 item from 4 items"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.items[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case: find top 1 item
    items = [
        (1, 101.1),   # Item-1
        (2, 555.22),  # Item-2 (highest)
        (3, 45.09),
        (4, 22.75),
        (5, 10.0),
        (6, 20.0),
        (7, 30.0),
        (8, 40.0)
    ]
    
    for i, (name_id, price) in enumerate(items):
        price_fp = to_fixed_point(price)
        # Format: name_id in lower 32 bits, price in upper 32 bits
        dut.items[i].value = (price_fp << 32) | name_id
    
    dut.n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (9 cycles total)
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.done_items.value == 1, f"Expected 1 item, got {dut.done_items.value}"
    
    result_item = dut.result[0].value
    result_price = result_item >> 32
    result_name = result_item & 0xFFFFFFFF
    
    expected_price = to_fixed_point(555.22)
    assert result_price == expected_price, f"Expected price {expected_price}, got {result_price}"
    assert result_name == 2, f"Expected name 2, got {result_name}"
    
    print(f"Test 1 passed: Top 1 item is Item-{result_name} with price {result_price}")

@cocotb.test()
async def test_top_items_finder_two_items(dut):
    """Test finding top 2 items from 4 items"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.items[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case: find top 2 items
    items = [
        (1, 101.1),
        (2, 555.22),  # Highest
        (3, 45.09),
        (4, 22.75),
        (5, 50.0),
        (6, 15.0),
        (7, 200.0),   # Second highest
        (8, 10.0)
    ]
    
    for i, (name_id, price) in enumerate(items):
        price_fp = to_fixed_point(price)
        dut.items[i].value = (price_fp << 32) | name_id
    
    dut.n.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.done_items.value == 2, f"Expected 2 items, got {dut.done_items.value}"
    
    # Check top 2
    result_price1 = dut.result[0].value >> 32
    result_name1 = dut.result[0].value & 0xFFFFFFFF
    result_price2 = dut.result[1].value >> 32
    result_name2 = dut.result[1].value & 0xFFFFFFFF
    
    expected_price1 = to_fixed_point(555.22)
    expected_price2 = to_fixed_point(200.0)
    
    assert result_price1 == expected_price1, f"First item price mismatch"
    assert result_price2 == expected_price2, f"Second item price mismatch"
    assert result_name1 == 2, f"First item should be Item-2"
    assert result_name2 == 7, f"Second item should be Item-7"
    
    print(f"Test 2 passed: Top 2 items are Item-{result_name1} and Item-{result_name2}")

@cocotb.test()
async def test_top_items_finder_three_items(dut):
    """Test finding top 3 items from 6 items"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.items[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case: find top 3 items
    items = [
        (1, 101.1),   # Third
        (2, 555.22),  # First
        (3, 45.09),
        (4, 22.75),
        (5, 300.0),   # Second
        (6, 15.0),
        (7, 50.0),
        (8, 10.0)
    ]
    
    for i, (name_id, price) in enumerate(items):
        price_fp = to_fixed_point(price)
        dut.items[i].value = (price_fp << 32) | name_id
    
    dut.n.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.done_items.value == 3, f"Expected 3 items, got {dut.done_items.value}"
    
    # Check top 3
    result_price1 = dut.result[0].value >> 32
    result_name1 = dut.result[0].value & 0xFFFFFFFF
    result_price2 = dut.result[1].value >> 32
    result_name2 = dut.result[1].value & 0xFFFFFFFF
    result_price3 = dut.result[2].value >> 32
    result_name3 = dut.result[2].value & 0xFFFFFFFF
    
    expected_price1 = to_fixed_point(555.22)
    expected_price2 = to_fixed_point(300.0)
    expected_price3 = to_fixed_point(101.1)
    
    assert result_price1 == expected_price1, f"First item price mismatch"
    assert result_price2 == expected_price2, f"Second item price mismatch"
    assert result_price3 == expected_price3, f"Third item price mismatch"
    assert result_name1 == 2, f"First item should be Item-2"
    assert result_name2 == 5, f"Second item should be Item-5"
    assert result_name3 == 1, f"Third item should be Item-1"
    
    print(f"Test 3 passed: Top 3 items are Item-{result_name1}, Item-{result_name2}, Item-{result_name3}")

@cocotb.test()
async def test_top_items_finder_edge_case(dut):
    """Test edge case: all items same price"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.items[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # All items have same price
    same_price = to_fixed_point(100.0)
    for i in range(8):
        dut.items[i].value = (same_price << 32) | (i+1)
    
    dut.n.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.done_items.value == 2, f"Expected 2 items, got {dut.done_items.value}"
    
    # All should be 100.0 price, names can be any (stable sort)
    result_price1 = dut.result[0].value >> 32
    result_price2 = dut.result[1].value >> 32
    
    assert result_price1 == same_price, f"Expected same price {same_price}"
    assert result_price2 == same_price, f"Expected same price {same_price}"
    
    print(f"Test 4 passed: Edge case with same prices handled correctly")

@cocotb.test()
async def test_top_items_finder_zero_items(dut):
    """Test finding 0 items (should output nothing)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.items[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Setup items
    items = [(1, 101.1), (2, 555.22), (3, 45.09), (4, 22.75), (5, 50.0), (6, 15.0), (7, 200.0), (8, 10.0)]
    for i, (name_id, price) in enumerate(items):
        price_fp = to_fixed_point(price)
        dut.items[i].value = (price_fp << 32) | name_id
    
    dut.n.value = 0  # Find 0 items
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.done_items.value == 0, f"Expected 0 items, got {dut.done_items.value}"
    
    print(f"Test 5 passed: Zero items case handled correctly")