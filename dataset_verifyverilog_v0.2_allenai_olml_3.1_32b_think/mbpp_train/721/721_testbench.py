import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_path_average(dut):
    """Test max path average calculation for 3x3 matrix"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.cost_0_0.value = 0
    dut.cost_0_1.value = 0
    dut.cost_0_2.value = 0
    dut.cost_1_0.value = 0
    dut.cost_1_1.value = 0
    dut.cost_1_2.value = 0
    dut.cost_2_0.value = 0
    dut.cost_2_1.value = 0
    dut.cost_2_2.value = 0
    
    # Wait for reset
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [[1, 2, 3], [6, 5, 4], [7, 3, 9]] -> Expected: 5.2
    # Path: 1->2->3->4->9 = 19, 19/5 = 3.8 (wrong path)
    # Actually: 1->6->7->8->9 or 1->2->6->7->9 or 1->6->5->9 or 1->2->5->9
    # Max sum path: 1->6->5->9? Let's calculate:
    # Path 1: right,right,down,down: 1+2+3+4+9 = 19, avg=3.8
    # Path 2: down,down,right,right: 1+6+7+8+9 = 31, avg=6.2 (but 8 not in matrix)
    # Wait, matrix is: [1,2,3], [6,5,4], [7,3,9]
    # Correct paths: Must be 2 down, 2 right in any order
    # Path: 1->6->7->3->9: 1+6+7+3+9=26, avg=5.2 ✓
    # Path: 1->2->5->3->9: 1+2+5+3+9=20, avg=4.0
    # Path: 1->6->5->4->9: 1+6+5+4+9=25, avg=5.0
    # So max is 26/5=5.2
    
    print("Test 1: Matrix [[1,2,3],[6,5,4],[7,3,9]]")
    dut.cost_0_0.value = 1
    dut.cost_0_1.value = 2
    dut.cost_0_2.value = 3
    dut.cost_1_0.value = 6
    dut.cost_1_1.value = 5
    dut.cost_1_2.value = 4
    dut.cost_2_0.value = 7
    dut.cost_2_1.value = 3
    dut.cost_2_2.value = 9
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 25 cycles for safety)
    for i in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 25 cycles")
    
    result = dut.result.value.integer
    expected = int(5.2 * 65536)  # 340787
    error = abs(result - expected)
    print(f"Result: {result} (Q16.16), Expected: {expected}, Error: {error}")
    print(f"Result as float: {result / 65536:.4f}")
    
    # Allow small rounding error (within 1/65536 ~ 0.000015)
    if error > 10:
        raise TestFailure(f"Result mismatch: got {result/65536:.4f}, expected {5.2}")
    
    print("Test 1 passed!
")
    
    # Test case 2: [[2,3,4],[7,6,5],[8,4,10]] -> Expected: 6.2
    # Max sum path: 2->7->8->4->10 = 31, avg=6.2 ✓
    print("Test 2: Matrix [[2,3,4],[7,6,5],[8,4,10]]")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.cost_0_0.value = 2
    dut.cost_0_1.value = 3
    dut.cost_0_2.value = 4
    dut.cost_1_0.value = 7
    dut.cost_1_1.value = 6
    dut.cost_1_2.value = 5
    dut.cost_2_0.value = 8
    dut.cost_2_1.value = 4
    dut.cost_2_2.value = 10
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = dut.result.value.integer
    expected = int(6.2 * 65536)  # 406323
    error = abs(result - expected)
    print(f"Result: {result} (Q16.16), Expected: {expected}, Error: {error}")
    print(f"Result as float: {result / 65536:.4f}")
    
    if error > 10:
        raise TestFailure(f"Result mismatch: got {result/65536:.4f}, expected {6.2}")
    
    print("Test 2 passed!
")
    
    # Test case 3: [[3,4,5],[8,7,6],[9,5,11]] -> Expected: 7.2
    # Max sum path: 3->8->9->5->11 = 36, avg=7.2 ✓
    print("Test 3: Matrix [[3,4,5],[8,7,6],[9,5,11]]")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.cost_0_0.value = 3
    dut.cost_0_1.value = 4
    dut.cost_0_2.value = 5
    dut.cost_1_0.value = 8
    dut.cost_1_1.value = 7
    dut.cost_1_2.value = 6
    dut.cost_2_0.value = 9
    dut.cost_2_1.value = 5
    dut.cost_2_2.value = 11
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = dut.result.value.integer
    expected = int(7.2 * 65536)  # 471859
    error = abs(result - expected)
    print(f"Result: {result} (Q16.16), Expected: {expected}, Error: {error}")
    print(f"Result as float: {result / 65536:.4f}")
    
    if error > 10:
        raise TestFailure(f"Result mismatch: got {result/65536:.4f}, expected {7.2}")
    
    print("Test 3 passed!
")
    
    # Test case 4: [[1,2,3],[4,5,6],[7,8,9]] -> Expected: 5.8
    # Max sum path: 1->4->7->8->9 = 29, avg=5.8 ✓
    print("Test 4: Matrix [[1,2,3],[4,5,6],[7,8,9]]")
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.cost_0_0.value = 1
    dut.cost_0_1.value = 2
    dut.cost_0_2.value = 3
    dut.cost_1_0.value = 4
    dut.cost_1_1.value = 5
    dut.cost_1_2.value = 6
    dut.cost_2_0.value = 7
    dut.cost_2_1.value = 8
    dut.cost_2_2.value = 9
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = dut.result.value.integer
    expected = int(5.8 * 65536)  # 380109
    error = abs(result - expected)
    print(f"Result: {result} (Q16.16), Expected: {expected}, Error: {error}")
    print(f"Result as float: {result / 65536:.4f}")
    
    if error > 10:
        raise TestFailure(f"Result mismatch: got {result/65536:.4f}, expected {5.8}")
    
    print("Test 4 passed!
")
    
    print("All 4 tests passed!")
