import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def calculate_exact_cycle_length(n, L, dist):
    """Check if any Hamiltonian cycle has exact length L"""
    if n == 1:
        return 0
    # Generate all permutations of nodes 1 to n-1
    nodes = list(range(1, n))
    import itertools
    for perm in itertools.permutations(nodes):
        total = dist[0][perm[0]]
        for i in range(len(perm)-1):
            total += dist[perm[i]][perm[i+1]]
        total += dist[perm[-1]][0]
        if total == L:
            return 1
    return 0

@cocotb.test()
async def test_orienteering_basic(dut):
    """Test basic case from sample input 1"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr_en.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load distance matrix: n=4, distances from sample
    # 0 3 2 1
    # 3 0 1 3
    # 2 1 0 2
    # 1 3 2 0
    dist_matrix = [
        [0, 3, 2, 1],
        [3, 0, 1, 3],
        [2, 1, 0, 2],
        [1, 3, 2, 0]
    ]
    
    for i in range(4):
        for j in range(4):
            dut.src_addr.value = i
            dut.dst_addr.value = j
            dut.dist_in.value = dist_matrix[i][j]
            dut.wr_en.value = 1
            await RisingEdge(dut.clk)
    
    dut.wr_en.value = 0
    
    # Set parameters and start
    dut.n.value = 4
    dut.L.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 10000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    # Check result
    assert dut.done.value == 1, "Did not complete in time"
    assert dut.result.value == 1, "Should be possible"
    print(f"Test 1 passed: result={dut.result.value}, done={dut.done.value}")

@cocotb.test()
async def test_orienteering_impossible(dut):
    """Test impossible case from sample input 2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr_en.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load distance matrix: n=3
    # 0 1 2
    # 1 0 3
    # 2 3 0
    dist_matrix = [
        [0, 1, 2],
        [1, 0, 3],
        [2, 3, 0]
    ]
    
    for i in range(3):
        for j in range(3):
            dut.src_addr.value = i
            dut.dst_addr.value = j
            dut.dist_in.value = dist_matrix[i][j]
            dut.wr_en.value = 1
            await RisingEdge(dut.clk)
    
    dut.wr_en.value = 0
    
    # L=5 should be impossible
    dut.n.value = 3
    dut.L.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 10000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Did not complete in time"
    assert dut.result.value == 0, "Should be impossible"
    print(f"Test 2 passed: result={dut.result.value}, done={dut.done.value}")

@cocotb.test()
async def test_orienteering_two_nodes(dut):
    """Test minimal case: n=2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr_en.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load distance matrix: n=2
    dist_matrix = [
        [0, 5],
        [5, 0]
    ]
    
    for i in range(2):
        for j in range(2):
            dut.src_addr.value = i
            dut.dst_addr.value = j
            dut.dist_in.value = dist_matrix[i][j]
            dut.wr_en.value = 1
            await RisingEdge(dut.clk)
    
    dut.wr_en.value = 0
    
    # Path 0->1->0 = 5+5 = 10
    dut.n.value = 2
    dut.L.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.result.value == 1
    print(f"Test 3 passed: result={dut.result.value}")

@cocotb.test()
async def test_orienteering_no_match(dut):
    """Test that correct length not found"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr_en.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Simple triangle: 0-1=1, 0-2=2, 1-2=3
    dist_matrix = [
        [0, 1, 2],
        [1, 0, 3],
        [2, 3, 0]
    ]
    
    for i in range(3):
        for j in range(3):
            dut.src_addr.value = i
            dut.dst_addr.value = j
            dut.dist_in.value = dist_matrix[i][j]
            dut.wr_en.value = 1
            await RisingEdge(dut.clk)
    
    dut.wr_en.value = 0
    
    # Paths: 0-1-2-0 = 1+3+2=6, 0-2-1-0 = 2+3+1=6. L=7 is impossible.
    dut.n.value = 3
    dut.L.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.result.value == 0
    print(f"Test 4 passed: result={dut.result.value}")

@cocotb.test()
async def test_orienteering_max_n(dut):
    """Test with n=7 to verify capacity"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr_en.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Create a simple graph where we know a specific cycle length
    # Use a star graph: 0 connected to all others with weight 1
    # Others connected with weight 100
    for i in range(7):
        for j in range(7):
            if i == j:
                val = 0
            elif i == 0 or j == 0:
                val = 1
            else:
                val = 100
            dut.src_addr.value = i
            dut.dst_addr.value = j
            dut.dist_in.value = val
            dut.wr_en.value = 1
            await RisingEdge(dut.clk)
    
    dut.wr_en.value = 0
    
    # Path 0->1->2->3->4->5->6->0
    # = 1 + 100*5 + 1 = 502
    dut.n.value = 7
    dut.L.value = 502
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.result.value == 1
    print(f"Test 5 passed: result={dut.result.value}")