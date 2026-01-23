import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

class LargeProductTester:
    def __init__(self, dut):
        self.dut = dut
        self.clk_period = 10
        
    async def reset(self):
        self.dut.rst_n.value = 0
        self.dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)
        
    async def compute_large_product(self, nums1, nums2, N):
        """Compute large product and return result list"""
        # Set inputs
        self.dut.size1.value = len(nums1)
        self.dut.size2.value = len(nums2)
        self.dut.N.value = N
        
        # Fill arrays
        for i in range(8):
            if i < len(nums1):
                self.dut.list1[i].value = nums1[i]
            else:
                self.dut.list1[i].value = 0
                
        for i in range(8):
            if i < len(nums2):
                self.dut.list2[i].value = nums2[i]
            else:
                self.dut.list2[i].value = 0
        
        # Start computation
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not self.dut.done.value and timeout < 3000:
            await RisingEdge(self.dut.clk)
            timeout += 1
            
        if timeout >= 3000:
            raise TestFailure("Timeout waiting for done signal")
            
        # Read results
        results = []
        valid_count = int(self.dut.valid_count.value)
        for i in range(min(N, valid_count)):
            val = int(self.dut.result[i].value)
            results.append(val)
            
        return results

@cocotb.test()
async def test_large_product_basic(dut):
    """Test Case 1: Basic functionality with N=3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    tester = LargeProductTester(dut)
    await tester.reset()
    
    # nums1 = [1,2,3,4,5,6], nums2 = [3,6,8,9,10,6], N=3
    # Expected: [60, 54, 50]
    nums1 = [1, 2, 3, 4, 5, 6]
    nums2 = [3, 6, 8, 9, 10, 6]
    N = 3
    
    results = await tester.compute_large_product(nums1, nums2, N)
    expected = [60, 54, 50]
    
    if results != expected:
        raise TestFailure(f"Expected {expected}, got {results}")
    
    print(f"Test 1 PASSED: {results}")

@cocotb.test()
async def test_large_product_n4(dut):
    """Test Case 2: N=4"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    tester = LargeProductTester(dut)
    await tester.reset()
    
    nums1 = [1, 2, 3, 4, 5, 6]
    nums2 = [3, 6, 8, 9, 10, 6]
    N = 4
    
    results = await tester.compute_large_product(nums1, nums2, N)
    expected = [60, 54, 50, 48]
    
    if results != expected:
        raise TestFailure(f"Expected {expected}, got {results}")
    
    print(f"Test 2 PASSED: {results}")

@cocotb.test()
async def test_large_product_n5(dut):
    """Test Case 3: N=5"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    tester = LargeProductTester(dut)
    await tester.reset()
    
    nums1 = [1, 2, 3, 4, 5, 6]
    nums2 = [3, 6, 8, 9, 10, 6]
    N = 5
    
    results = await tester.compute_large_product(nums1, nums2, N)
    expected = [60, 54, 50, 48, 45]
    
    if results != expected:
        raise TestFailure(f"Expected {expected}, got {results}")
    
    print(f"Test 3 PASSED: {results}")

@cocotb.test()
async def test_large_product_small_arrays(dut):
    """Test Case 4: Small arrays, N larger than products"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    tester = LargeProductTester(dut)
    await tester.reset()
    
    nums1 = [10, 20]
    nums2 = [2, 3]
    N = 4
    
    # Products: 20, 30, 40, 60 -> sorted: [60, 40, 30, 20]
    results = await tester.compute_large_product(nums1, nums2, N)
    expected = [60, 40, 30, 20]
    
    if results != expected:
        raise TestFailure(f"Expected {expected}, got {results}")
    
    print(f"Test 4 PASSED: {results}")

@cocotb.test()
async def test_large_product_single_element(dut):
    """Test Case 5: Single element lists"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    tester = LargeProductTester(dut)
    await tester.reset()
    
    nums1 = [5]
    nums2 = [8]
    N = 1
    
    # Product: 40
    results = await tester.compute_large_product(nums1, nums2, N)
    expected = [40]
    
    if results != expected:
        raise TestFailure(f"Expected {expected}, got {results}")
    
    print(f"Test 5 PASSED: {results}")

@cocotb.test()
async def test_large_product_edge_case(dut):
    """Test Case 6: Large numbers causing overflow check"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    tester = LargeProductTester(dut)
    await tester.reset()
    
    nums1 = [200, 250]
    nums2 = [255, 200]
    N = 2
    
    # Products: 51000, 50000, 62500, 50000 -> sorted: [62500, 51000]
    results = await tester.compute_large_product(nums1, nums2, N)
    expected = [62500, 51000]
    
    if results != expected:
        raise TestFailure(f"Expected {expected}, got {results}")
    
    print(f"Test 6 PASSED: {results}")

print("All large_product tests completed")