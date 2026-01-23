import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

async def setup_dut(dut):
    """Initialize DUT with reset sequence"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_stores.value = 0
    dut.num_items.value = 0
    
    for i in range(8):
        dut.purchase_order[i].value = 0
        dut.inventory_matrix[i].value = 0
    
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    return clock

@cocotb.test()
async def test_impossible_case(dut):
    """Test case 1: No valid path exists"""
    clock = await setup_dut(dut)
    
    # Setup: 3 stores, 3 items
    # purchase_order = [0, 2, 1] (chocolate, cookies, icecream)
    # inventory:
    # store0: item0 (chocolate) -> 0b001
    # store1: item1 (icecream) -> 0b010  
    # store2: item2 (cookies) -> 0b100
    # But order is chocolate(0), cookies(2), icecream(1)
    # Need store0->store2->store1, but check if valid
    
    dut.num_stores.value = 3
    dut.num_items.value = 3
    dut.purchase_order[0].value = 0  # chocolate
    dut.purchase_order[1].value = 2  # cookies
    dut.purchase_order[2].value = 1  # icecream
    
    dut.inventory_matrix[0].value = 0b001  # store0 has item0
    dut.inventory_matrix[1].value = 0b010  # store1 has item1
    dut.inventory_matrix[2].value = 0b100  # store2 has item2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 256 cycles)
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Module did not complete within 300 cycles")
    
    if dut.result.value != 0:
        raise TestFailure(f"Test 1: Expected 0 (impossible), got {dut.result.value}")
    
    print("Test 1 passed: impossible case")

@cocotb.test()
async def test_unique_case(dut):
    """Test case 2: Exactly one valid path"""
    clock = await setup_dut(dut)
    
    # Setup: 3 stores, 3 items
    # purchase_order = [0, 1, 2] (chocolate, icecream, cookies)
    # inventory:
    # store0: item0 -> 0b001
    # store1: item1 -> 0b010
    # store2: item2 -> 0b100
    # Also store2 has item0 (chocolate)
    # Only valid path: [0, 1, 2]
    
    dut.num_stores.value = 3
    dut.num_items.value = 3
    dut.purchase_order[0].value = 0
    dut.purchase_order[1].value = 1
    dut.purchase_order[2].value = 2
    
    dut.inventory_matrix[0].value = 0b001  # store0: item0
    dut.inventory_matrix[1].value = 0b010  # store1: item1
    dut.inventory_matrix[2].value = 0b100  # store2: item2
    # store2 also has item0: 0b101 (but already set)
    # Actually need to add: store0 has item0, store1 has item1, store2 has items2 and 0
    dut.inventory_matrix[2].value = 0b101  # store2: item0, item2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Module did not complete within 300 cycles")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 2: Expected 1 (unique), got {dut.result.value}")
    
    print("Test 2 passed: unique case")

@cocotb.test()
async def test_ambiguous_case(dut):
    """Test case 3: Multiple valid paths"""
    clock = await setup_dut(dut)
    
    # Setup: 3 stores, 5 items
    # purchase_order = [0, 1, 2, 3, 4] (tomatoes, cucumber, salad, mustard, salt)
    # inventory:
    # store0: items0,1,4 -> 0b10011 (tomatoes, cucumber, salt)
    # store1: items0,3 -> 0b1001 (tomatoes, mustard)
    # store2: items2,3,4 -> 0b11100 (salad, mustard, salt)
    # Multiple paths possible
    
    dut.num_stores.value = 3
    dut.num_items.value = 5
    dut.purchase_order[0].value = 0  # tomatoes
    dut.purchase_order[1].value = 1  # cucumber
    dut.purchase_order[2].value = 2  # salad
    dut.purchase_order[3].value = 3  # mustard
    dut.purchase_order[4].value = 4  # salt
    
    dut.inventory_matrix[0].value = 0b10011  # store0: 0,1,4
    dut.inventory_matrix[1].value = 0b1001   # store1: 0,3
    dut.inventory_matrix[2].value = 0b11100  # store2: 2,3,4
    
    # Clear unused high bits
    dut.inventory_matrix[3].value = 0
    dut.inventory_matrix[4].value = 0
    dut.inventory_matrix[5].value = 0
    dut.inventory_matrix[6].value = 0
    dut.inventory_matrix[7].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Module did not complete within 300 cycles")
    
    if dut.result.value != 2:
        raise TestFailure(f"Test 3: Expected 2 (ambiguous), got {dut.result.value}")
    
    print("Test 3 passed: ambiguous case")

@cocotb.test()
async def test_single_item_unique(dut):
    """Test case 4: Single item purchase, unique"""
    clock = await setup_dut(dut)
    
    dut.num_stores.value = 2
    dut.num_items.value = 1
    dut.purchase_order[0].value = 0
    
    dut.inventory_matrix[0].value = 0b01  # store0 has item0
    dut.inventory_matrix[1].value = 0b10  # store1 has item1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Module did not complete")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 4: Expected 1 (unique), got {dut.result.value}")
    
    print("Test 4 passed: single item unique")

@cocotb.test()
async def test_early_termination(dut):
    """Test case 5: Early termination when 2 paths found"""
    clock = await setup_dut(dut)
    
    # Simple case where multiple stores have same item
    dut.num_stores.value = 3
    dut.num_items.value = 2
    dut.purchase_order[0].value = 0
    dut.purchase_order[1].value = 1
    
    # Both store0 and store1 have item0, store2 has item1
    dut.inventory_matrix[0].value = 0b01  # store0: item0
    dut.inventory_matrix[1].value = 0b01  # store1: item0
    dut.inventory_matrix[2].value = 0b10  # store2: item1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(300):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: Module did not complete")
    
    # Should be ambiguous since both [0,2] and [1,2] are valid
    if dut.result.value != 2:
        raise TestFailure(f"Test 5: Expected 2 (ambiguous), got {dut.result.value}")
    
    print("Test 5 passed: early termination")

@cocotb.test()
async def test_max_constraints(dut):
    """Test case 6: Max constraints (8 stores, 8 items)"""
    clock = await setup_dut(dut)
    
    # Use edge case: all stores sell all items
    dut.num_stores.value = 8
    dut.num_items.value = 8
    
    for i in range(8):
        dut.purchase_order[i].value = i
        dut.inventory_matrix[i].value = 0xFF  # All items available
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # This will take many cycles but should terminate (early detection)
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 6: Module did not complete")
    
    # Should be ambiguous (8^8 possibilities, way more than 2)
    if dut.result.value != 2:
        raise TestFailure(f"Test 6: Expected 2 (ambiguous), got {dut.result.value}")
    
    print("Test 6 passed: max constraints")