import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

class NestedListFlattener:
    def __init__(self, dut):
        self.dut = dut
        self.dut.rst_n.value = 1
        self.dut.start.value = 0
        self.dut.num_subarrays.value = 0
        for i in range(4):
            self.dut.subarray_lengths[i].value = 0
        for i in range(16):
            self.dut.data_in[i].value = 0
    
    async def reset(self):
        self.dut.rst_n.value = 0
        await Timer(10, units='ns')
        await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)
    
    async def flatten(self, nested_list):
        # Convert nested list to flat representation
        flat_data = []
        sub_lens = []
        
        for sublist in nested_list:
            sub_lens.append(len(sublist))
            flat_data.extend(sublist)
        
        # Pad to 16 elements if needed
        while len(flat_data) < 16:
            flat_data.append(0)
        
        # Set inputs
        self.dut.num_subarrays.value = len(nested_list)
        for i in range(4):
            if i < len(sub_lens):
                self.dut.subarray_lengths[i].value = sub_lens[i]
            else:
                self.dut.subarray_lengths[i].value = 0
        
        for i in range(16):
            self.dut.data_in[i].value = flat_data[i]
        
        # Start computation
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        
        # Wait for completion
        timeout = 50
        for _ in range(timeout):
            if self.dut.done.value == 1:
                break
            await RisingEdge(self.dut.clk)
        else:
            raise TestFailure("Timeout waiting for done signal")
        
        # Read output
        result = []
        out_len = int(self.dut.output_length.value)
        for i in range(out_len):
            result.append(int(self.dut.flattened[i].value))
        
        return result

@cocotb.test()
async def test_flatten_basic(dut):
    """Test basic flattening of 2D array"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    flattener = NestedListFlattener(dut)
    await flattener.reset()
    
    # Test case 1: [[0, 10], [20, 30], [40, 50], [60, 70]]
    nested1 = [[0, 10], [20, 30], [40, 50], [60, 70]]
    result1 = await flattener.flatten(nested1)
    expected1 = [0, 10, 20, 30, 40, 50, 60, 70]
    
    if len(result1) != len(expected1):
        raise TestFailure(f"Length mismatch: got {len(result1)}, expected {len(expected1)}")
    
    for i, (got, exp) in enumerate(zip(result1, expected1)):
        if got != exp:
            raise TestFailure(f"Index {i}: got {got}, expected {exp}")
    
    dut._log.info(f"Test 1 passed: {result1}")

@cocotb.test()
async def test_flatten_mixed_lengths(dut):
    """Test with sub-arrays of varying lengths"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    flattener = NestedListFlattener(dut)
    await flattener.reset()
    
    # Test case 2: [[10, 20], [40], [30, 56, 25], [10, 20]]
    nested2 = [[10, 20], [40], [30, 56, 25], [10, 20]]
    result2 = await flattener.flatten(nested2)
    expected2 = [10, 20, 40, 30, 56, 25, 10, 20]
    
    if len(result2) != len(expected2):
        raise TestFailure(f"Length mismatch: got {len(result2)}, expected {len(expected2)}")
    
    for i, (got, exp) in enumerate(zip(result2, expected2)):
        if got != exp:
            raise TestFailure(f"Index {i}: got {got}, expected {exp}")
    
    dut._log.info(f"Test 2 passed: {result2}")

@cocotb.test()
async def test_flatten_single_subarray(dut):
    """Test with single sub-array"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    flattener = NestedListFlattener(dut)
    await flattener.reset()
    
    # Test case 3: [[1, 2, 3, 4]]
    nested3 = [[1, 2, 3, 4]]
    result3 = await flattener.flatten(nested3)
    expected3 = [1, 2, 3, 4]
    
    if result3 != expected3:
        raise TestFailure(f"Got {result3}, expected {expected3}")
    
    dut._log.info(f"Test 3 passed: {result3}")

@cocotb.test()
async def test_flatten_four_subarrays(dut):
    """Test with 4 sub-arrays"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    flattener = NestedListFlattener(dut)
    await flattener.reset()
    
    # Test case 4: [[1,2,3], [4,5,6], [10,11,12], [7,8,9]]
    nested4 = [[1,2,3], [4,5,6], [10,11,12], [7,8,9]]
    result4 = await flattener.flatten(nested4)
    expected4 = [1, 2, 3, 4, 5, 6, 10, 11, 12, 7, 8, 9]
    
    if len(result4) != len(expected4):
        raise TestFailure(f"Length mismatch: got {len(result4)}, expected {len(expected4)}")
    
    for i, (got, exp) in enumerate(zip(result4, expected4)):
        if got != exp:
            raise TestFailure(f"Index {i}: got {got}, expected {exp}")
    
    dut._log.info(f"Test 4 passed: {result4}")

@cocotb.test()
async def test_flatten_empty_subarrays(dut):
    """Test with some empty sub-arrays"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    flattener = NestedListFlattener(dut)
    await flattener.reset()
    
    # Test case 5: [[5, 6], [], [7, 8], []]
    nested5 = [[5, 6], [], [7, 8], []]
    result5 = await flattener.flatten(nested5)
    expected5 = [5, 6, 7, 8]
    
    if len(result5) != len(expected5):
        raise TestFailure(f"Length mismatch: got {len(result5)}, expected {len(expected5)}")
    
    for i, (got, exp) in enumerate(zip(result5, expected5)):
        if got != exp:
            raise TestFailure(f"Index {i}: got {got}, expected {exp}")
    
    dut._log.info(f"Test 5 passed: {result5}")

@cocotb.test()
async def test_flatten_max_elements(dut):
    """Test with maximum elements (4x4=16)"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    flattener = NestedListFlattener(dut)
    await flattener.reset()
    
    # Test case 6: [[0,1,2,3], [4,5,6,7], [8,9,10,11], [12,13,14,15]]
    nested6 = [[0,1,2,3], [4,5,6,7], [8,9,10,11], [12,13,14,15]]
    result6 = await flattener.flatten(nested6)
    expected6 = list(range(16))
    
    if result6 != expected6:
        raise TestFailure(f"Got {result6}, expected {expected6}")
    
    dut._log.info(f"Test 6 passed: {result6}")
