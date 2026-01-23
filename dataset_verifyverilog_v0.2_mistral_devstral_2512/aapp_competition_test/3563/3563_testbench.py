import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_min_lines_convex(dut):
    """Test minimum lines computation for convex polygon points"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to set points
    def set_points(n, coords):
        dut.n.value = n
        for i in range(8):
            if i < n:
                dut.x_coords[i].value = coords[i][0]
                dut.y_coords[i].value = coords[i][1]
            else:
                dut.x_coords[i].value = 0
                dut.y_coords[i].value = 0
    
    # Helper function to run test
    async def run_test(n, coords, expected):
        set_points(n, coords)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        assert timeout < 500, "Timeout waiting for done"
        assert dut.result.value == expected, f"Expected {expected}, got {int(dut.result.value)}"
        print(f"Test passed: n={n}, result={int(dut.result.value)}")
    
    # Test 1: Square (4 points) - needs 2 lines
    # Points: (0,0), (1,1), (1,0), (0,1)
    # On convex boundary, can be covered by 2 lines
    await run_test(4, [(0,0), (1,1), (1,0), (0,1)], 2)
    
    # Test 2: Hexagon-like (8 points) - needs 3 lines
    # Points from sample: (0,0), (2,2), (0,2), (2,0), (1,0), (1,2), (0,1), (2,1)
    # This is an octagon-like shape
    await run_test(8, [(0,0), (2,2), (0,2), (2,0), (1,0), (1,2), (0,1), (2,1)], 3)
    
    # Test 3: Triangle (3 points) - needs 1 line
    await run_test(3, [(0,0), (1,0), (0,1)], 1)
    
    # Test 4: Line of 5 points - needs 1 line
    await run_test(5, [(0,0), (1,1), (2,2), (3,3), (4,4)], 1)
    
    # Test 5: Alternating points - needs 4 lines for 8 points
    await run_test(8, [(0,0), (10,0), (1,1), (9,1), (2,2), (8,2), (3,3), (7,3)], 4)
    
    print("All tests passed!")