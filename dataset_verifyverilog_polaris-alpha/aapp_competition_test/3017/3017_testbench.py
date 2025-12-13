import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

async def reset_dut(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.start.value = 0

# Convert string to 5-digit BCD array (left-padded with zeros)
def str_to_bcd(s):
    s = s.zfill(5)
    return [int(c) for c in s]

@cocotb.test()
async def test_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    test_cases = [
        # n, e, expected_count (human-calculated for scaled-down inputs)
        # Original: n=1000000 e=1 → 468559, scaled n=999 e=1 (power_str="2    
        (32, 1, 13),  # Numbers 0-32 containing "2": 2,12,20-29 (total 13)
        (100, 3, 19), # Numbers 0-100 containing "8" (2^3=8) → 8,18,...,98, 80-89 → 19
        (50, 4, 3),   # Numbers containing "16" (2^4=16) → 16, 160+ out of scope → only 16
    ]
    passed = 0
    for i, (n_val, e_val, expected) in enumerate(test_cases):
        # Precompute power string and length for testbench (input to DUT)
        power_val = pow(2, e_val)
        power_str = str(power_val).zfill(5)
        bcd_digits = str_to_bcd(power_str)
        dut.n.value = n_val
        for j in range(5):
            dut.power_str.value = bcd_digits[j]
        dut.substr_len.value = len(power_str.lstrip('0')) or 1  # Handle e=0 case
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"Test {i} passed: count={dut.count.value}")
        else:
            dut._log.error(f"Test {i} failed: got {dut.count.value} vs {expected}, n={n_val} e={e_val} (power={power_val} as '{power_str}')")
        
        # Reset between tests
        await reset_dut(dut)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)