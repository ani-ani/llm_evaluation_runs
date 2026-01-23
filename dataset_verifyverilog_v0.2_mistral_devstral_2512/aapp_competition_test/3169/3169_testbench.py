import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Helper to map python list to module inputs
def set_inputs(dut, sticks, n_sticks):
    inputs = [
        (dut.s0_x1, dut.s0_y1, dut.s0_x2, dut.s0_y2),
        (dut.s1_x1, dut.s1_y1, dut.s1_x2, dut.s1_y2),
        (dut.s2_x1, dut.s2_y1, dut.s2_x2, dut.s2_y2),
        (dut.s3_x1, dut.s3_y1, dut.s3_x2, dut.s3_y2),
        (dut.s4_x1, dut.s4_y1, dut.s4_x2, dut.s4_y2),
        (dut.s5_x1, dut.s5_y1, dut.s5_x2, dut.s5_y2),
        (dut.s6_x1, dut.s6_y1, dut.s6_x2, dut.s6_y2),
        (dut.s7_x1, dut.s7_y1, dut.s7_x2, dut.s7_y2),
    ]
    
    # Initialize all to 0
    for i in range(8):
        inputs[i][0].value = 0
        inputs[i][1].value = 0
        inputs[i][2].value = 0
        inputs[i][3].value = 0
        
    for i in range(n_sticks):
        x1, y1, x2, y2 = sticks[i]
        inputs[i][0].value = x1
        inputs[i][1].value = y1
        inputs[i][2].value = x2
        inputs[i][3].value = y2
        
    dut.n_sticks.value = n_sticks

@cocotb.test()
async def test_stick_sorter_basic(dut):
    """Test stick ordering logic"""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From example 1 (Scaled down to fit N=8)
    # Input: 
    # 0: 1 3 2 2 (Stick 0)
    # 1: 1 1 3 2 (Stick 1)
    # 2: 2 4 7 3 (Stick 2)
    # 3: 3 3 5 3 (Stick 3)
    # Expected Output: 2 4 1 3 (Indices: 1, 3, 0, 2)
    
    sticks = [
        (1, 3, 2, 2), # Stick 0
        (1, 1, 3, 2), # Stick 1
        (2, 4, 7, 3), # Stick 2
        (3, 3, 5, 3), # Stick 3
    ]
    
    set_inputs(dut, sticks, 4)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise AssertionError("Timeout waiting for done signal")

    # Read results
    order = [
        int(dut.order_0.value),
        int(dut.order_1.value),
        int(dut.order_2.value),
        int(dut.order_3.value),
    ]
    
    # Filter out indices for N=4
    valid_order = [x for x in order if x < 4]
    print(f"Result order: {valid_order}")
    
    # Verify Topological Sort properties
    # 1. All indices 0-3 must be present exactly once
    assert sorted(valid_order) == [0, 1, 2, 3], f"Invalid permutation: {valid_order}"
    
    # 2. Verify blocking constraints
    # Helper to check if A blocks B
    def does_block(a_idx, b_idx):
        ax1, ay1, ax2, ay2 = sticks[a_idx]
        bx1, by1, bx2, by2 = sticks[b_idx]
        
        # X overlap
        a_min_x = min(ax1, ax2)
        a_max_x = max(ax1, ax2)
        b_min_x = min(bx1, bx2)
        b_max_x = max(bx1, bx2)
        
        overlap = (a_max_x >= b_min_x) and (a_min_x <= b_max_x)
        
        # Height: A is strictly higher (using average Y)
        # If avg Y is same, they don't block (strictly translation needed)
        # But let's stick to strict average comparison for simplicity
        avg_a = (ay1 + ay2) / 2.0
        avg_b = (by1 + by2) / 2.0
        higher = avg_a > avg_b
        
        return overlap and higher
    
    # Check dependencies: if A blocks B, A must come before B in removal order
    # (Wait, if A blocks B, A is above B. We remove A first to free B)
    # So A must appear before B in the output list.
    
    for i in range(4):
        for j in range(4):
            if i == j: continue
            if does_block(i, j):
                # i blocks j, so i must come before j in valid_order
                try:
                    idx_i = valid_order.index(i)
                    idx_j = valid_order.index(j)
                    assert idx_i < idx_j, f"Constraint violated: Stick {i} blocks Stick {j}, so {i} must be before {j}. Order: {valid_order}"
                except ValueError:
                    # Should not happen given permutation check
                    pass
                    
    print("Test 1 Passed")

@cocotb.test()
async def test_stick_sorter_cycle_case(dut):
    """Test a case where sticks don't block each other or are in complex partial order"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input: 3 sticks
    # 0: 4 6 5 5 (High, left)
    # 1: 2 1 15 1 (Low, wide)
    # 2: 3 2 8 7 (Mid, diagonal)
    # Expected: 2 3 1 (Indices: 1, 2, 0)
    
    sticks = [
        (4, 6, 5, 5),
        (2, 1, 15, 1),
        (3, 2, 8, 7),
    ]
    
    set_inputs(dut, sticks, 3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    order = [
        int(dut.order_0.value),
        int(dut.order_1.value),
        int(dut.order_2.value),
    ]
    valid_order = [x for x in order if x < 3]
    print(f"Result order: {valid_order}")
    
    assert sorted(valid_order) == [0, 1, 2], f"Invalid permutation: {valid_order}"
    
    # Verify constraints
    def does_block(a_idx, b_idx):
        ax1, ay1, ax2, ay2 = sticks[a_idx]
        bx1, by1, bx2, by2 = sticks[b_idx]
        a_min_x = min(ax1, ax2); a_max_x = max(ax1, ax2)
        b_min_x = min(bx1, bx2); b_max_x = max(bx1, bx2)
        overlap = (a_max_x >= b_min_x) and (a_min_x <= b_max_x)
        avg_a = (ay1 + ay2) / 2.0
        avg_b = (by1 + by2) / 2.0
        higher = avg_a > avg_b
        return overlap and higher

    for i in range(3):
        for j in range(3):
            if i == j: continue
            if does_block(i, j):
                try:
                    idx_i = valid_order.index(i)
                    idx_j = valid_order.index(j)
                    assert idx_i < idx_j, f"Constraint violated: Stick {i} blocks Stick {j}"
                except ValueError:
                    pass
                    
    print("Test 2 Passed")