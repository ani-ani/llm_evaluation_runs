import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_function_decomp(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("valid_1", [1,2,3,4,5,6,7,8], 8, [1,2,3,4,5,6,7,8], [1,2,3,4,5,6,7,8], 1), # Full sequence
        ("valid_2", [2,2,2,2,2,2,2,2], 1, [1,1,1,1,1,1,1,1], [2], 1),            # All same values
        ("invalid", [2,1,3,4,5,6,7,8], 0, [0]*8, [0]*8, 0)                     # Invalid case f[0]=2 but f[2-1]!=2
    ]
    
    passed = 0
    for name, f_in, exp_m, exp_g, exp_h, exp_valid in test_cases:
        # Apply inputs
        for i in range(8):
            dut.f[i].value = f_in[i]-1  # Convert to 0-based indexing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation (5 cycles)
        for _ in range(5):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.valid_out.value != exp_valid:
            dut._log.error(f"{name} failed: valid_out={dut.valid_out.value} != {exp_valid}")
        else:
            if exp_valid:
                m_val = int(dut.m.value)
                if m_val != exp_m:
                    dut._log.error(f"{name} failed: m={m_val} != {exp_m}")
                else:
                    g_ok = all(int(dut.g[i].value)+1 == exp_g[i] for i in range(8))
                    h_ok = all(int(dut.h[i].value)+1 == exp_h[i] for i in range(m_val))
                    
                    if g_ok and h_ok:
                        passed += 1
                    else:
                        dut._log.error(f"{name} failed: g={[int(dut.g[i].value)+1 for i in range(8)]} h={[int(dut.h[i].value)+1 for i in range(m_val)]}")
            else:
                passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")