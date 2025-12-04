import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_perfect_squares(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 30, [1, 4, 9, 16, 25]),
        (50, 100, [64, 81, 100]),
        (100, 200, [100, 121, 144, 169, 196])
    ]
    passed = 0
    
    for a, b, expected in test_cases:
        # Apply inputs
        dut.a.value = a
        dut.b.value = b
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        results = []
        timeout = 20  # Max cycles per test
        
        # Wait for processing
        while not dut.done.value:
            await RisingEdge(dut.clk)
            if dut.valid.value == 1:
                results.append(int(dut.square_out.value))
            
            timeout -= 1
            if timeout <= 0:
                break
        
        # Final check when done
        if results == expected:
            passed += 1
            dut._log.info(f"PASS: ({a},{b}) -> {results}")
        else:
            dut._log.error(f"FAIL: ({a},{b}) got {results}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)