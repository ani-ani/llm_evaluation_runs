import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_chip_allocator(dut):
    """Test chip allocator with various battery configurations"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {
            "name": "Sample 1: 2 machines, 3 batteries per chip",
            "batteries": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            "total": 12,
            "expected": 1  # After sorting: [1,2,3,4,5,6,7,8,9,10,11,12], pairs (1,2)=1, (3,4)=1, (5,6)=1, (7,8)=1, max=1
        },
        {
            "name": "Sample 2: 2 machines, 2 batteries per chip",
            "batteries": [3, 1, 3, 3, 3, 3, 3, 3],
            "total": 8,
            "expected": 2  # Sorted: [1,3,3,3,3,3,3,3], pairs (1,3)=2, (3,3)=0, (3,3)=0, (3,3)=0, max=2
        },
        {
            "name": "All equal",
            "batteries": [5, 5, 5, 5, 5, 5, 5, 5],
            "total": 8,
            "expected": 0
        },
        {
            "name": "Alternating high-low",
            "batteries": [1, 10, 2, 9, 3, 8, 4, 7],
            "total": 8,
            "expected": 1  # Sorted: [1,2,3,4,7,8,9,10], pairs (1,2)=1, (3,4)=1, (7,8)=1, (9,10)=1, max=1
        },
        {
            "name": "Edge case: small values",
            "batteries": [1, 255, 1, 255],
            "total": 4,
            "expected": 254
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Running test {i+1}: {test['name']}")
        
        # Load batteries
        for j in range(12):
            if j < test['total']:
                dut.battery_powers[j].value = test['batteries'][j]
            else:
                dut.battery_powers[j].value = 0
        
        dut.total_batteries.value = test['total']
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"Test {i+1}: Timeout waiting for done")
            continue
        
        result = int(dut.min_difference.value)
        expected = test['expected']
        
        if result == expected:
            dut._log.info(f"Test {i+1} PASSED: Got {result}, Expected {expected}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Got {result}, Expected {expected}")
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
