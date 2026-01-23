import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def compute_expected(arr):
    """Compute expected sum of products for test cases"""
    ans = 0
    res = 0
    i = len(arr) - 1
    while i >= 0:
        incr = arr[i] * (1 + res)
        ans += incr
        res = incr
        i -= 1
    return ans

@cocotb.test()
async def test_sum_of_products_basic(dut):
    """Test basic functionality with small arrays"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1,2,3] -> expected 20
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.array_size.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 20
    if result != expected:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected}")
    print(f"Test 1 passed: [1,2,3] -> {result}")
    
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_sum_of_products_two_elements(dut):
    """Test with two elements"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [1,2] -> expected 5
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.array_size.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 5
    if result != expected:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected}")
    print(f"Test 2 passed: [1,2] -> {result}")
    
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_sum_of_products_four_elements(dut):
    """Test with four elements"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [1,2,3,4] -> expected 84
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 4
    dut.array_size.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 84
    if result != expected:
        raise TestFailure(f"Test 3 failed: got {result}, expected {expected}")
    print(f"Test 3 passed: [1,2,3,4] -> {result}")
    
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_sum_of_products_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single element: [5] -> expected 5
    dut.arr[0].value = 5
    dut.array_size.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 5
    if result != expected:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected}")
    print(f"Test 4 passed: [5] -> {result}")
    
    await RisingEdge(dut.clk)
    
    # Zeros: [0,2,0] -> subarrays: [0]=0, [2]=2, [0]=0, [0,2]=0, [2,0]=0, [0,2,0]=0 -> sum=2
    dut.arr[0].value = 0
    dut.arr[1].value = 2
    dut.arr[2].value = 0
    dut.array_size.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 2
    if result != expected:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected}")
    print(f"Test 5 passed: [0,2,0] -> {result}")
    
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_sum_of_products_large_values(dut):
    """Test with larger values to check overflow handling"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # [10,20,30] -> check calculation
    # subarrays: [10]=10, [20]=20, [30]=30, [10,20]=200, [20,30]=600, [10,20,30]=6000
    # sum = 10+20+30+200+600+6000 = 6860
    dut.arr[0].value = 10
    dut.arr[1].value = 20
    dut.arr[2].value = 30
    dut.array_size.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 6860
    if result != expected:
        raise TestFailure(f"Test 6 failed: got {result}, expected {expected}")
    print(f"Test 6 passed: [10,20,30] -> {result}")
    
    await RisingEdge(dut.clk)
    
    # Print summary
    print("
=== Test Summary ===")
    print("All 6 tests passed successfully!")
    print("Verified: [1,2,3]=20, [1,2]=5, [1,2,3,4]=84, [5]=5, [0,2,0]=2, [10,20,30]=6860")