import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def float_to_q16_16(f):
    return int(f * (1 << 16))

def q16_16_to_float(q):
    return q / (1 << 16) if q < 0x80000000 else (q - 0x100000000) / (1 << 16)

@cocotb.test()
async def test_mad(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (converted to Q16.16, extended to 4 elements)
    test_cases = [
        [[1.0, 2.0, 3.0, 0.0], 2.0/3.0],  # Original had 3 elements
        [[1.0, 2.0, 3.0, 4.0], 1.0],
        [[1.0, 2.0, 3.0, 4.0], 1.0],  # Duplicate for delay testing
        [[1.0, 2.0, 3.0, 5.0], 6.0/5.0]  # Original 5 elements → last case approximated with 4
    ]
    
    passed = 0
    for inputs, expected in test_cases:
        # Convert inputs
        q_inputs = [float_to_q16_16(x) for x in inputs]
        
        # Apply inputs
        dut.num0.value = q_inputs[0]
        dut.num1.value = q_inputs[1]
        dut.num2.value = q_inputs[2]
        dut.num3.value = q_inputs[3]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(11):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result with 0.5% tolerance (≈ 9 bits precision)
        actual_float = q16_16_to_float(int(dut.mad.value))
        tolerance = 0.005 * abs(expected)
        
        if abs(actual_float - expected) < max(tolerance, 1e-3):
            passed += 1
            dut._log.info(f"PASS: Result {actual_float:.4f} ≈ {expected:.4f}")
        else:
            dut._log.error(f"FAIL: Inputs {inputs} → {actual_float:.4f}, expected {expected:.4f}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")