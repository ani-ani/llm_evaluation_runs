import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time
import math

@cocotb.test()
async def test_max_fruits(dut):
    # Fixed-point conversion helper
    def fp(num):
        return int(num * (1 << 16)) if abs(num) <= 32768 else 0
    
    # Test cases (original scaled to n<=8 with fp conversion)
    test_cases = [
        (5, [
            (1.00, 5.00), (3.00, 3.00), (4.00, 2.00), (6.00, 4.50), (7.00, 1.00), 
            (0.00, 0.00), (0.00, 0.00), (0.00, 0.00)
        ], 4),
        (3, [
            (-1.50, -1.00), (1.50, -1.00), (0.00, 1.00), (0.00, 0.00), 
            (0.00, 0.00), (0.00, 0.00), (0.00, 0.00), (0.00, 0.00)
        ], 3),
        (2, [
            (1.00, 1.00), (1.00, 1.00), (0.00, 0.00), (0.00, 0.00), 
            (0.00, 0.00), (0.00, 0.00), (0.00, 0.00), (0.00, 0.00)
        ], 2)
    ]
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for test_num, (n_in, coords, expected) in enumerate(test_cases):
        dut._log.info(f"Starting test #{test_num}")
        
        # Reset and initialization
        dut.rst_n.value = 0
        dut.start.value = 0
        for i in range(8):
            dut.x[i].value = 0
            dut.y[i].value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load test data
        dut.n.value = n_in
        for i in range(8):
            x_val, y_val = coords[i]
            dut.x[i].value = fp(x_val)
            dut.y[i].value = fp(y_val)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (up to 300 cycles)
        cycles_waited = 0
        while not dut.done.value and cycles_waited < 300:
            await RisingEdge(dut.clk)
            cycles_waited += 1
        
        # Check result
        if cycles_waited >= 300:
            dut._log.error("Timeout waiting for done signal")
        elif dut.max_count.value == expected:
            dut._log.info(f"Test #{test_num} passed")
            passed += 1
        else:
            dut._log.error(f"Test #{test_num} failed: got {dut.max_count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
