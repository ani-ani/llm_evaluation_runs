import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

# Q24.8 conversion functions
def float_to_q248(f):
    return int(f * (1 << 8)) & 0xFFFFFFFF

def q248_to_float(i):
    return (i if i < 0x80000000 else i - 0x100000000) / 256.0

@cocotb.test()
async def test_spiral(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    
    # Test cases [b, tx, ty, expected_x, expected_y]
    test_cases = [
        (0.5, -5.301, 3.098, -1.26167861, 3.88425357),
        (0.5, 8, 8, 9.21068947, 2.56226688),
        (1, 8, 8, 6.22375968, -0.31921472),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for b_in, tx_in, ty_in, exp_x, exp_y in test_cases:
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs in Q24.8 format
        dut.b_q248.value = float_to_q248(b_in)
        dut.tx_q248.value = float_to_q248(tx_in)
        dut.ty_q248.value = float_to_q248(ty_in)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (128 cycles)
        for _ in range(150):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Convert outputs to floats
        result_x = q248_to_float(dut.x_out_q248.value)
        result_y = q248_to_float(dut.y_out_q248.value)
        
        # Check within absolute tolerance (0.0001)
        x_ok = abs(result_x - exp_x) < 1e-4
        y_ok = abs(result_y - exp_y) < 1e-4
        
        if x_ok and y_ok:
            passed += 1
        else:
            dut._log.error("Test failed: Input (b=%.3f, tx=%.3f, ty=%.3f)\\
                Output (x=%.8f, y=%.8f) Expected (x=%.8f, y=%.8f)" % 
                (b_in, tx_in, ty_in, result_x, result_y, exp_x, exp_y))
    
    dut._log.info(f"{passed}/{total} tests passed")