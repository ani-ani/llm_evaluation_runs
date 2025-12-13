import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_rocket_fuel(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled to n<=8)
    test_cases = [
        (2, 12, [11,8]+[1]*6, [7,5]+[1]*6, 10.0),
        (3, 1, [1,4,1]+[1]*5, [2,5,3]+[1]*5, -1),
        (6, 2, [4,6,3,3,5,6,1,1], [2,6,3,6,5,3,1,1], 85.48),
        (8, 4, [1,1,4,1,3,1,8,1], [1,1,1,1,1,3,1,2], -1)
    ]
    
    # Test parameters
    Q_SCALE = 1 << 16  # Q16.16 scaling factor
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n, m, a_list, b_list, expected in test_cases:
        # Setup inputs
        dut.n.value = n
        dut.m.value = int(m * Q_SCALE)
        
        for i in range(8):
            dut.a[i].value = a_list[i]
            dut.b[i].value = b_list[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        done_count = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            done_count += 1
            if done_count > 20:
                break
                
        # Check results
        if expected < 0:
            # Error case expected
            if int(dut.fuel.value) == 0xFFFFFFFFFF:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected error (-1), got {dut.fuel.value / Q_SCALE}")
        else:
            # Verify result within 0.1% tolerance
            actual = dut.fuel.value / Q_SCALE
            if math.isclose(actual, expected, rel_tol=0.001):
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected {expected}, got {actual}")
        
        # Reset for next case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Print summary
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
