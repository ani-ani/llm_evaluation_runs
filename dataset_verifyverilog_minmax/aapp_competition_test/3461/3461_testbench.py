import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_hearing_scheduler(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Defaults
    dut.start.value = 0
    
    # Reset procedure
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1 (Scaled from sample input)
    # Original: 4 hearings with sample values
    test_cases = [
        {
            'num': 4,
            's': [1, 3, 5, 6],
            'a': [1, 2, 1, 10],
            'b': [7, 3, 4, 10],
            'expected': 2.125 * 65536  # Q16.16 value for 2.125
        },
        {
            'num': 3,
            's': [1, 3, 5],
            'a': [1, 2, 1],
            'b': [2, 3, 2],
            'expected': 2.5 * 65536  # Q16.16 value for 2.5
        }
    ]
    
    passed = 0
    tolerance = 655  # 0.01 tolerance in Q16.16
    
    for tc in test_cases:
        # Set inputs
        dut.num_hearings.value = tc['num']
        for i in range(4):
            if i < tc['num']:
                dut.s[i].value = tc['s'][i]
                dut.a[i].value = tc['a'][i]
                dut.b[i].value = tc['b'][i]
            else:
                dut.s[i].value = 0
                dut.a[i].value = 0
                dut.b[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 256 cycles)
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 300:
            dut._log.error("Test timeout!")
        else:
            # Check result
            actual = dut.result.value.signed_integer / 65536.0
            expected = tc['expected'] / 65536.0
            if abs(dut.result.value.integer - tc['expected']) <= tolerance:
                passed += 1
                dut._log.info(f"Test passed: Expected {expected:.3f}, got {actual:.3f}")
            else:
                dut._log.error(f"Test failed: Expected {expected:.3f} ({tc['expected']}), got {actual:.3f} ({dut.result.value.integer})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"