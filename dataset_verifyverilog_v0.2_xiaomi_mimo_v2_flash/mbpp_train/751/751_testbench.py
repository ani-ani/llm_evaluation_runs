import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_check_min_heap(dut):
    """Test min-heap checker with various arrays"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Min-Heap Checker Test Results ===")
    tests_passed = 0
    tests_total = 0
    
    # Test 1: Valid min-heap [1, 2, 3, 4, 5, 6, 7, 8]
    # arr[0]=1: children arr[1]=2, arr[2]=3 -> 1<=2, 1<=3 ✓
    # arr[1]=2: children arr[3]=4, arr[4]=5 -> 2<=4, 2<=5 ✓
    # arr[2]=3: children arr[5]=6, arr[6]=7 -> 3<=6, 3<=7 ✓
    # arr[3]=4: children arr[7]=8 -> 4<=8 ✓
    tests_total += 1
    dut.arr.value = [1, 2, 3, 4, 5, 6, 7, 8]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (should take 5 more cycles: CHECK_1 through DONE)
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    if dut.done.value and dut.is_heap.value:
        print(f"Test 1 PASSED: [1,2,3,4,5,6,7,8] is heap: {int(dut.is_heap.value)}")
        tests_passed += 1
    else:
        print(f"Test 1 FAILED: Expected is_heap=1, got {int(dut.is_heap.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: Valid min-heap [2, 3, 4, 5, 10, 15, 16, 17]
    # arr[0]=2: children arr[1]=3, arr[2]=4 -> 2<=3, 2<=4 ✓
    # arr[1]=3: children arr[3]=5, arr[4]=10 -> 3<=5, 3<=10 ✓
    # arr[2]=4: children arr[5]=15, arr[6]=16 -> 4<=15, 4<=16 ✓
    # arr[3]=5: children arr[7]=17 -> 5<=17 ✓
    tests_total += 1
    dut.arr.value = [2, 3, 4, 5, 10, 15, 16, 17]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    if dut.done.value and dut.is_heap.value:
        print(f"Test 2 PASSED: [2,3,4,5,10,15,16,17] is heap: {int(dut.is_heap.value)}")
        tests_passed += 1
    else:
        print(f"Test 2 FAILED: Expected is_heap=1, got {int(dut.is_heap.value)}")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: Invalid min-heap [2, 10, 4, 5, 3, 15, 16, 17]
    # arr[0]=2: children arr[1]=10, arr[2]=4 -> 2<=10, 2<=4 ✓
    # arr[1]=10: children arr[3]=5, arr[4]=3 -> 10<=5 ✗ FAIL
    tests_total += 1
    dut.arr.value = [2, 10, 4, 5, 3, 15, 16, 17]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    if dut.done.value and not dut.is_heap.value:
        print(f"Test 3 PASSED: [2,10,4,5,3,15,16,17] is not heap: {int(dut.is_heap.value)}")
        tests_passed += 1
    else:
        print(f"Test 3 FAILED: Expected is_heap=0, got {int(dut.is_heap.value)}")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: Edge case - all equal values [5,5,5,5,5,5,5,5] (valid heap)
    tests_total += 1
    dut.arr.value = [5, 5, 5, 5, 5, 5, 5, 5]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    if dut.done.value and dut.is_heap.value:
        print(f"Test 4 PASSED: [5,5,5,5,5,5,5,5] is heap: {int(dut.is_heap.value)}")
        tests_passed += 1
    else:
        print(f"Test 4 FAILED: Expected is_heap=1, got {int(dut.is_heap.value)}")
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: Invalid - right child violation [1,2,3,4,5,6,1,7]
    # arr[2]=3: children arr[5]=6, arr[6]=1 -> 3<=6 ✓, 3<=1 ✗ FAIL
    tests_total += 1
    dut.arr.value = [1, 2, 3, 4, 5, 6, 1, 7]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    if dut.done.value and not dut.is_heap.value:
        print(f"Test 5 PASSED: [1,2,3,4,5,6,1,7] is not heap: {int(dut.is_heap.value)}")
        tests_passed += 1
    else:
        print(f"Test 5 FAILED: Expected is_heap=0, got {int(dut.is_heap.value)}")
    
    print(f"
=== Summary: {tests_passed}/{tests_total} tests passed ===")
    
    if tests_passed != tests_total:
        raise TestFailure(f"Only {tests_passed} out of {tests_total} tests passed")