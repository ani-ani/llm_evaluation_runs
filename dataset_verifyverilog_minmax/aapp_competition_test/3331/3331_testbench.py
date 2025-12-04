import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_horse_chase(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (5,4,3,2,3),  # Original sample
        (5,4,2,3,3),  # Sample with swapped B,P
        (6,5,0,3,3),  # Horse between cows
        (15,15,0,7,5),  # Larger case
        (2,0,2,1,1)    # Immediate capture
    ]
    
    await Timer(15, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    for L, A, B, P, expected in test_cases:
        # Apply test inputs
        dut.L.value = L
        dut.A.value = A
        dut.B.value = B
        dut.P.value = P
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.time_out.value.integer
        if actual == expected:
            passed += 1
            dut._log.info(f"Test passed for {A},{B},{P}->{actual}")
        else:
            dut._log.error(f"Failed for L={L}, A={A}, B={B}, P={P}: {actual} vs {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
