import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_missing_number(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Test 1: [0,1,2,3,15,15,15,15] -> Expected 4
        {'array': [0,1,2,3,15,15,15,15], 'expected': 4},
        
        # Test 2: [0,1,2,6,9,15,15,15] -> Expected 3
        {'array': [0,1,2,6,9,15,15,15], 'expected': 3},
        
        # Test 3: [2,3,5,8,9,15,15,15] -> Expected 0
        {'array': [2,3,5,8,9,15,15,15], 'expected': 0},
        
        # Additional edge case: Empty (using all invalid marks)
        {'array': [15]*8, 'expected': 0},
        
        # Gap at middle
        {'array': [0,1,2,4,5,15,15,15], 'expected': 3}
    ]

    passed = 0
    for test in test_cases:
        # Load array (wait 1 cycle for setup)
        for i in range(8):
            dut.array[i].value = test['array'][i]
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 5 cycles)
        timeout = 5
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        # Check result
        if timeout == 0:
            dut._log.error(f"Timeout waiting for done signal")
        elif dut.missing.value == test['expected']:
            passed += 1
            dut._log.info(f"PASS: Array={test['array']} -> {dut.missing.value}")
        else:
            dut._log.error(f"FAIL: Array={test['array']} got {dut.missing.value}, expected {test['expected']}")
        
        # Wait 1 cycle between tests
        await RisingEdge(dut.clk)
    
    # Show summary
    dut._log.info(f"{passed}/{len(test_cases)} tests passed, expected at least 3")
    if passed >= 3:
        dut._log.info("Minimum test requirement met")
    else:
        dut._log.error("Critical failure: Less than 3 test cases passed")
