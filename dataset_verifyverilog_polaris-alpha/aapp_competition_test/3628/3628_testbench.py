import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_crypto(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # Sample Input 1 (n=5 extended to n=8 with padding)
        {"a": [3,2,3,1,1,0,0,0], "expected_pi": [1,4,3,5,2,6,7,8], "expected_sigma": [2,3,5,1,4,6,7,8], "valid": True},
        # Sample Input 2 (n=4 extended to n=8)
        {"a": [3,1,1,4,0,0,0,0], "valid": False}
    ]
    
    passed = 0
    for test in test_cases:
        # Reset system
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Apply inputs
        for i in range(8):
            dut.a[i].value = test["a"][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (exit early if test takes too long)
        timeout = 1000
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        # Check outputs
        if timeout == 0:
            dut._log.error("Test timed out")
        elif test["valid"]:
            if dut.valid.value != 1:
                dut._log.error(f"Solution should exist but not found for a={test['a']}")
            else:
                # Verify permutations satisfy conditions
                match = True
                for i in range(8):
                    pi_val = dut.pi[i].value
                    sigma_val = dut.sigma[i].value
                    calc = (pi_val + sigma_val) % 8
                    if calc != dut.a[i].value % 8 and dut.a[i].value != 0:
                        match = False
                if match:
                    passed += 1
                else:\
                    dut._log.error("Produced permutations don't match conditions")
        else:
            if dut.impossible.value != 1:
                dut._log.error(f"Expected impossible for a={test['a']}")
            else:
                passed += 1
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
