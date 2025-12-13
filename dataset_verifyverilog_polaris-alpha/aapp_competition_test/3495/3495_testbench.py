import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

# Fixed-point conversion functions
def float_to_q16_16(f):
    return int(f * 65536) & 0xFFFFFFFF

def q16_16_to_float(val):
    if val >= 0x80000000:
        val -= 0x100000000
    return val / 65536.0

@cocotb.test()
async def test_arm(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    tolerance = 0.01
    
    # Test cases (scaled to fixed-point)
    test_cases = [
        (3, [5,3,4], (5.0, 3.0), [
            (4.114, -2.842),
            (6.297, -0.784),
            (5.000, 3.000)
        ]),
        (2, [4,2], (-8.0, -3.0), [
            (-3.745, -1.404),
            (-5.618, -2.107)
        ])
    ]
    
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n, lengths, target, positions in test_cases:
        # Apply inputs
        dut.N.value = n
        for i in range(8):
            if i < len(lengths):
                dut.__setattr__(f"L_{i}", int(lengths[i]))
            else:
                dut.__setattr__(f"L_{i}", 0)
        
        dut.target_x.value = float_to_q16_16(target[0])
        dut.target_y.value = float_to_q16_16(target[1])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(n + 1):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        valid = True
        for i in range(n):
            x = q16_16_to_float(dut.__getattr__(f"x_{i}").value)
            y = q16_16_to_float(dut.__getattr__(f"y_{i}").value)
            
            # Check distance tolerance
            dist = math.hypot(x - positions[i][0], y - positions[i][1])
            if dist > tolerance:
                dut._log.error(f"Segment {i} pos error: ({x:.3f},{y:.3f}) vs expected ({positions[i][0]:.3f},{positions[i][1]:.3f}) dist={dist:.4f}")
                valid = False
        
        if valid:
            passed += 1
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"