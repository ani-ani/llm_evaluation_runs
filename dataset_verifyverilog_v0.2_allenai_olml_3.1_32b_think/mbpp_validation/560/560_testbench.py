import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to pack a list of values into the expected 8-element array format
def pack_array(values):
    arr = [0xFF] * 8  # Initialize with sentinel
    for i, v in enumerate(values):
        if i < 8:
            arr[i] = v
    return arr

async def run_test(dut, tup1_list, tup2_list, expected_list):
    # Convert lists to packed arrays for the dut
    dut._log.info(f"Inputs: {tup1_list}, {tup2_list}")
    
    # Pack inputs into 8-element arrays
    in1 = pack_array(tup1_list)
    in2 = pack_array(tup2_list)
    
    # Drive inputs
    for i in range(8):
        dut.tuple1[i].value = in1[i]
        dut.tuple2[i].value = in2[i]
    
    dut.start.value = 0
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 500 # Safety timeout
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout: done signal not asserted")
    
    # Read result
    result = []
    for i in range(8):
        val = int(dut.result[i].value)
        result.append(val)
        
    # Prepare expected
    expected_packed = pack_array(sorted(expected_list))
    
    # Compare
    if result != expected_packed:
        dut._log.error(f"Result mismatch: got {result}, expected {expected_packed}")
        raise TestFailure("Output does not match expected")
    
    dut._log.info("Test Passed")

@cocotb.test()
async def test_union_sort_basic(dut):
    """Test basic union of two tuples with overlapping elements"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(20, units="ns")
    
    # Test Case 1 from original problem (adapted to smaller subset to fit max 8 unique elements)
    # Original: (3,4,5,6) + (5,7,4,10) -> sorted unique: 3,4,5,6,7,10
    # Inputs need to be 8 elements padded with 0
    tup1 = [3, 4, 5, 6, 0, 0, 0, 0]
    tup2 = [5, 7, 4, 10, 0, 0, 0, 0]
    expected = [3, 4, 5, 6, 7, 10]
    
    await run_test(dut, tup1, tup2, expected)

@cocotb.test()
async def test_union_sort_no_overlap(dut):
    """Test union with no overlapping elements"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(20, units="ns")
    
    # Test Case 2 subset: (1,2) + (5,6)
    tup1 = [1, 2, 0, 0, 0, 0, 0, 0]
    tup2 = [5, 6, 0, 0, 0, 0, 0, 0]
    expected = [1, 2, 5, 6]
    
    await run_test(dut, tup1, tup2, expected)

@cocotb.test()
async def test_union_sort_duplicates(dut):
    """Test union with duplicates within each tuple"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(20, units="ns")
    
    # Inputs: (1, 2, 2, 3) + (3, 4, 4, 5)
    # Union: 1, 2, 3, 4, 5
    tup1 = [1, 2, 2, 3, 0, 0, 0, 0]
    tup2 = [3, 4, 4, 5, 0, 0, 0, 0]
    expected = [1, 2, 3, 4, 5]
    
    await run_test(dut, tup1, tup2, expected)

@cocotb.test()
async def test_union_sort_full(dut):
    """Test union filling all 8 output slots (8 unique elements)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(20, units="ns")
    
    # Inputs: (1, 3, 5, 7) + (2, 4, 6, 8) -> Union: 1..8
    tup1 = [1, 3, 5, 7, 0, 0, 0, 0]
    tup2 = [2, 4, 6, 8, 0, 0, 0, 0]
    expected = [1, 2, 3, 4, 5, 6, 7, 8]
    
    await run_test(dut, tup1, tup2, expected)
