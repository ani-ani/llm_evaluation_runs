import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess

async def assign_wishes(dut, friend_idx, wishes_list):
    """
    Helper to encode Python wish list into the 32-bit vector expected by Verilog.
    Format: 4 wishes per friend, packed into 32 bits (8 bits per wish).
    Wish bits: [3:0] = Topping Index (0-7), [4] = Type (1 for +, 0 for -), rest unused.
    """
    val = 0
    for i, wish_str in enumerate(wishes_list):
        if wish_str.startswith('+'):
            t_type = 1
            topping = int(wish_str[1:])
        else:
            t_type = 0
            topping = int(wish_str[1:])
        
        # Pack into byte 'i'
        byte_val = (topping & 0x07) | (t_type << 3)
        val |= (byte_val << (i * 8))
    
    dut.wishes[friend_idx].value = val

@cocotb.test()
async def test_pizza_solver(dut):
    """Test the pizza constraint solver."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_friends.value = 0
    dut.num_toppings.value = 0
    for i in range(4):
        dut.wishes[i].value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test Case 1: Single friend, 4 wishes (3+, 1-) ---
    # Input: 4 +0 +1 +2 -3
    # Target: Select {0, 1, 2}, Avoid {3} -> Selection mask = 0b00001111 (assuming top 4 bits map to toppings 0-3? 
    # Wait, mask bits: bit 0 = topping 0, bit 1 = topping 1...)
    # 0b00001111 -> Toppings 0, 1, 2, 3 selected. 
    # Check: 
    # +0: selected (Yes) -> Happy
    # +1: selected (Yes) -> Happy
    # +2: selected (Yes) -> Happy
    # -3: selected (Bad) -> Sad. Total Happy=3.
    # 3 > 4/3 (1.33) -> Valid.
    # Another valid: 0b00001110 (0,1,2 selected). 3 excluded.
    # Happy: 3/3. Valid.
    
    await assign_wishes(dut, 0, ['+0', '+1', '+2', '-3'])
    dut.num_friends.value = 1
    dut.num_toppings.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for found signal
    timeout = 0
    while not dut.found.value and timeout < 400:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.found.value:
        raise TestFailure("Test Case 1: Failed to find solution in time")
        
    selection = dut.selection.value
    # Check if the selection satisfies the constraint
    # We verify the logic by checking the constraint in Python for the found selection
    happy_count = 0
    # Wish 0 (+0): check bit 0
    if (selection & 1): happy_count += 1
    # Wish 1 (+1): check bit 1
    if (selection & 2): happy_count += 1
    # Wish 2 (+2): check bit 2
    if (selection & 4): happy_count += 1
    # Wish 3 (-3): check bit 3 (must be 0)
    if not (selection & 8): happy_count += 1
    
    if happy_count * 3 <= 4:
        raise TestFailure(f"Test Case 1: Invalid selection {bin(selection)}, happy_count {happy_count}")
    
    dut._log.info(f"Test 1 Passed: Selection {bin(selection)} gave {happy_count}/4 satisfied")
    await RisingEdge(dut.clk)

    # --- Test Case 2: 3 Friends, 3 wishes each ---
    # Inputs from problem statement converted to indices:
    # Assume Toppings: redbeans=0, soylentgreen=1, bluecheese=2
    # Friend 1: 3 +0 +1 -2
    # Friend 2: 3 +0 -1 +2
    # Friend 3: 3 -0 +1 +2
    
    await assign_wishes(dut, 0, ['+0', '+1', '-2'])
    await assign_wishes(dut, 1, ['+0', '-1', '+2'])
    await assign_wishes(dut, 2, ['-0', '+1', '+2'])
    
    dut.num_friends.value = 3
    dut.num_toppings.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.found.value and timeout < 400:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.found.value:
        raise TestFailure("Test Case 2: Failed to find solution")
    
    selection = dut.selection.value
    # Verify Friend 1 (+0, +1, -2)
    f1_happy = 0
    if (selection & 1): f1_happy += 1 # +0
    if (selection & 2): f1_happy += 1 # +1
    if not (selection & 4): f1_happy += 1 # -2
    
    # Verify Friend 2 (+0, -1, +2)
    f2_happy = 0
    if (selection & 1): f2_happy += 1 # +0
    if not (selection & 2): f2_happy += 1 # -1
    if (selection & 4): f2_happy += 1 # +2
    
    # Verify Friend 3 (-0, +1, +2)
    f3_happy = 0
    if not (selection & 1): f3_happy += 1 # -0
    if (selection & 2): f3_happy += 1 # +1
    if (selection & 4): f3_happy += 1 # +2
    
    if f1_happy * 3 <= 3 or f2_happy * 3 <= 3 or f3_happy * 3 <= 3:
        raise TestFailure(f"Test Case 2: Invalid selection {bin(selection)}. Counts: {f1_happy}, {f2_happy}, {f3_happy}")
        
    dut._log.info(f"Test 2 Passed: Selection {bin(selection)} gave {f1_happy}, {f2_happy}, {f3_happy} satisfied")
    await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")