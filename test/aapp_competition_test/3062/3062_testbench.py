import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_hovercraft(dut):
    # Convert float to Q16.16 fixed-point
    def to_q16_16(val):
        return int(val * (1 << 16)) 
    
    # Create clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (original scaled to 4 representatives)
    test_cases = [
        (20.0, 0.0, 1.00, 0.10, 20.0),              # Straight line
        (-10.0, 10.0, 10.00, 1.00, math.pi),        # Diagonal move (pi seconds)
        (0.0, 20.0, 1.00, 0.10, 28.26445910),       # Vertical
        (-997.0, -3.0, 5.64, 2.15, 177.76915187)    # Complex case
    ]
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for x, y, v, w, expected in test_cases:
        # Apply inputs in fixed-point
        dut.x_pos.value = to_q16_16(x)
        dut.y_pos.value = to_q16_16(y)
        dut.velocity.value = to_q16_16(v)
        dut.omega.value = to_q16_16(w)
        dut.start.value = 1
        
        # Wait 10 cycles for computation
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(10):
            await RisingEdge(dut.clk)
            
        # Check output with 0.001 tolerance (655 in Q16.16)
        result = dut.min_time.value.signed_integer / (1 << 16)
        if abs(result - expected) <= 0.001:
            passed += 1
            dut._log.info(f"Test passed: {result:.8f} vs {expected:.8f}")
        else:
            dut._log.error(f"Test failed: {result:.8f} vs {expected:.8f}")
    
    # Final report
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")