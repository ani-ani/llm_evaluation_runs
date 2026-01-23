import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper to convert signed 32-bit int to binary string
def to_bin(val, width=32):
    if val < 0:
        val = (1 << width) + val
    return format(val, f'0{width}b')

@cocotb.test()
async def test_laser_fence_basic(dut):
    """Test basic case: 3 onions, 5 posts, K=3, expecting 2 protected onions."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Inputs for Test Case 1:
    # N=3, M=5, K=3
    # Onions: (1,1), (2,2), (1,3)
    # Posts: (0,0), (0,3), (1,4), (3,3), (3,0)
    
    dut.num_onions.value = 3
    dut.num_posts.value = 5
    dut.select_k.value = 3
    
    # Start signal
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load Data Sequence
    # Format: data_type: 0=Onion, 1=Post
    data_stream = [
        (0, 1, 1),   # Onion 1
        (0, 2, 2),   # Onion 2
        (0, 1, 3),   # Onion 3
        (1, 0, 0),   # Post 1
        (1, 0, 3),   # Post 2
        (1, 1, 4),   # Post 3
        (1, 3, 3),   # Post 4
        (1, 3, 0),   # Post 5
    ]
    
    for d_type, x, y in data_stream:
        dut.data_type.value = d_type
        dut.data_in.value = x
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
        dut.data_in.value = y
        await RisingEdge(dut.clk)
        # Note: The Verilog might expect X and Y in separate cycles or same cycle. 
        # Assuming strictly sequential X then Y based on "data_in" width.
        # If "data_in" is 32-bit, X and Y must be packed or passed sequentially.
        # I'll assume X on cycle 1, Y on cycle 2 for each point.
        # Wait for the Verilog to consume. 
        # The prompt says: data_in [31:0], data_valid. 
        # To be safe, I'll toggle valid high for each coordinate.
        # Re-evaluating prompt: "wait for data_valid signals. Store onions..."
        # "data_in [31:0]: Coordinate data (X, Y)". This implies a stream.
        # I'll send X then Y with valid high each time.
    
    dut.data_valid.value = 0
    
    # Wait for computation
    max_cycles = 5000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check result
    if dut.done.value != 1:
        raise TestFailure(f"Module did not finish within {max_cycles} cycles")
        
    # Expected output is 2
    if int(dut.result) != 2:
        raise TestFailure(f"Expected result 2, got {int(dut.result)}")
    
    dut._log.info("Test 1 Passed: Result 2")


@cocotb.test()
async def test_laser_fence_second(dut):
    """Test second case: 5 onions, 6 posts, K=4, expecting 4 protected onions."""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Inputs for Test Case 2:
    # N=5, M=6, K=4
    # Onions: (3,5), (5,5), (4,4), (7,2), (5,2)
    # Posts: (6,1), (4,2), (2,6), (5,6), (8,3), (8,2)
    
    dut.num_onions.value = 5
    dut.num_posts.value = 6
    dut.select_k.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    data_stream = [
        (0, 3, 5), (0, 5, 5), (0, 4, 4), (0, 7, 2), (0, 5, 2),
        (1, 6, 1), (1, 4, 2), (1, 2, 6), (1, 5, 6), (1, 8, 3), (1, 8, 2),
    ]
    
    for d_type, x, y in data_stream:
        dut.data_type.value = d_type
        dut.data_in.value = x
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        dut.data_in.value = y
        await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    # Wait for computation
    max_cycles = 5000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure(f"Module did not finish within {max_cycles} cycles")
        
    # Expected output is 4
    if int(dut.result) != 4:
        raise TestFailure(f"Expected result 4, got {int(dut.result)}")
    
    dut._log.info("Test 2 Passed: Result 4")

@cocotb.test()
async def test_laser_fence_single_hull(dut):
    """Edge case: 3 onions inside a triangle of 3 posts (K=3)."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 3 onions at (1,1), (2,1), (1,2) -> Inside triangle (0,0), (3,0), (0,3)
    dut.num_onions.value = 3
    dut.num_posts.value = 3
    dut.select_k.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    data_stream = [
        (0, 1, 1), (0, 2, 1), (0, 1, 2),
        (1, 0, 0), (1, 3, 0), (1, 0, 3),
    ]
    
    for d_type, x, y in data_stream:
        dut.data_type.value = d_type
        dut.data_in.value = x
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        dut.data_in.value = y
        await RisingEdge(dut.clk)
        
    dut.data_valid.value = 0
    
    max_cycles = 5000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if int(dut.result) != 3:
        raise TestFailure(f"Expected 3, got {int(dut.result)}")
    
    dut._log.info("Test 3 Passed: All 3 inside")