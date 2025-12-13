import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_gon_prob(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (adapted with 4-char max)
    # Format: (g_str, k_str, p_float, expected_float)
    test_cases = [
        # Original samples converted:
        ('H', 'T', 0.5, 0.5),  # 0x008000 Q16.8
        ('HH', 'TH', 0.5, 0.25), # 0x004000 Q16.8
        # Added tests within 4-char limit:
        ('HHH', 'HHT', 0.5, 0.125), # Gon first wins when HHH appears before HHT
        ('HT', 'TH', 0.6, 0.36) # p^2*(1-p) + p*(1-p)*(p) = 0.6*0.4*0.6 + 0.6*0.4*0.6 = 0.288
    ]
    passed = 0
    tol = 1e-4  # Tolerance fixed-point precision check

    for g_str, k_str, p_float, expected in test_cases:
        # Convert strings to 4-bit patterns (0=H,1=T)
        def str_to_bits(s):
            bits = 0
            for c in s[::-1]:
                bits = (bits << 1) | (1 if c == 'T' else 0)
            return bits & 0xF  # Mask to 4 bits
        
        g_bits = str_to_bits(g_str)
        k_bits = str_to_bits(k_str)
        p_fixed = int(p_float * (1 << 8)) & 0xFFFF  # Q8.8 conversion
        expected_fixed = int(expected * (1 << 8)) # Q16.8 value (LS 8-bit fractional)
        
        # Apply inputs
        dut.g.value = g_bits
        dut.k.value = k_bits
        dut.p.value = p_fixed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check outputs
        result = dut.prob_out.value.integer / (1 << 8) # Convert Q16.8 to float
        error = abs(result - expected)
        rel_error = error / max(1.0, expected)
        
        if rel_error <= 1e-4:  # Check within 0.01% error
            passed += 1
        else:
            dut._log.error(f"Test failed: g={g_str}, k={k_str}, p={p_float}\\\\\
                Expected {expected} ({hex(expected_fixed)}), got {result} ({hex(dut.prob_out.value)})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")