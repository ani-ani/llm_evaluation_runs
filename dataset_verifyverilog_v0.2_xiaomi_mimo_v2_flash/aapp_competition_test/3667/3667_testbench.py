import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_pipe_bipartite(dut):
    """Test the pipe bipartite checker with scaled inputs."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_pipe.value = 0
    dut.pipe_idx.value = 0
    dut.sx.value = 0
    dut.sy.value = 0
    dut.ex.value = 0
    dut.ey.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Impossible (Sample Input 1)
    # Original: 3 wells, 3 pipes
    # Wells: (0,0), (0,2), (2,0)
    # Pipes: 
    # 1: from (0,0) to (2,3)
    # 2: from (0,2) to (2,2)
    # 3: from (2,0) to (0,3)
    # Scaled coordinates (divide by 1000): 
    # Pipe 0 (idx 0): s(0,0) e(2,3)
    # Pipe 1 (idx 1): s(0,2) e(2,2)
    # Pipe 2 (idx 2): s(2,0) e(0,3)
    # We must provide 8 pipes. Fill rest with zero length or dummy.
    
    pipes = [
        (0, 0, 2, 3),  # 0
        (0, 2, 2, 2),  # 1
        (2, 0, 0, 3),  # 2
        (0, 0, 0, 0),  # 3 (dummy)
        (0, 0, 0, 0),  # 4
        (0, 0, 0, 0),  # 5
        (0, 0, 0, 0),  # 6
        (0, 0, 0, 0),  # 7
    ]

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed pipes
    for i in range(8):
        sx, sy, ex, ey = pipes[i]
        dut.pipe_idx.value = i
        dut.sx.value = sx
        dut.sy.value = sy
        dut.ex.value = ex
        dut.ey.value = ey
        dut.valid_pipe.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_pipe.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 1: Timeout waiting for done")

    if dut.result.value != 0:
        raise TestFailure(f"Test 1 Expected Impossible (0), got {dut.result.value}")
    print("Test 1 passed: Impossible")

    await RisingEdge(dut.clk)
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Possible
    # Input: 2 3
    # Wells: (0,0), (0,10)
    # Pipes:
    # 1: from (0,0) to (5,15)
    # 1: from (0,0) to (2,15)  <-- Wait, input says "1 5 15" and "1 2 15". Two pipes from well 1.
    # 2: from (0,10) to (10,10)
    # Scaled: (0,0)-(5,15), (0,0)-(2,15), (0,10)-(10,10)
    
    pipes = [
        (0, 0, 5, 15),  # 0
        (0, 0, 2, 15),  # 1
        (0, 10, 10, 10), # 2
        (0, 0, 0, 0),  # 3
        (0, 0, 0, 0),  # 4
        (0, 0, 0, 0),  # 5
        (0, 0, 0, 0),  # 6
        (0, 0, 0, 0),  # 7
    ]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(8):
        sx, sy, ex, ey = pipes[i]
        dut.pipe_idx.value = i
        dut.sx.value = sx
        dut.sy.value = sy
        dut.ex.value = ex
        dut.ey.value = ey
        dut.valid_pipe.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_pipe.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 500:
        raise TestFailure("Test 2: Timeout waiting for done")

    if dut.result.value != 1:
        raise TestFailure(f"Test 2 Expected Possible (1), got {dut.result.value}")
    print("Test 2 passed: Possible")
