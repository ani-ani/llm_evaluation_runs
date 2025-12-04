import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_tax(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    test_cases = [
        # (n, k, denominations, expected_total, expected_g)
        (2, 8, [12, 20], 2, 4),  # Original: 2
0 4 
        (3, 10, [10,20,30], 1, 10),  # 1
0 
        (5, 10, [20,16,4,16,2], 5, 2),  # 5
0 2 4 6 8 
        (1, 10, [1], 10, 1),  # 10
0-9 (wont fit in output)
        (2, 30, [6,10], 15, 2)  # Divisors: step=2 (gcd(30,2)=2) total=15
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (n, k, denoms, exp_total, exp_g) in test_cases:
        # Load inputs
        dut.n.value = n
        dut.k.value = k
        for i in range(8):
            den_val = denoms[i] % k if i < len(denoms) else 0
            setattr(dut, f'denomination_{i}', den_val)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        total = dut.total.value
        g = dut.g.value
        is_correct = (total == exp_total and g == exp_g)
        div_digits = list(range(0, k, g)) if g >0 else [0]
        
        if is_correct:
            passed += 1
            dut._log.info(f"TC Pass: n={n}, k={k} => total={total}, g={g}, digits={div_digits}")
        else:
            dut._log.error(f"Test failed: n={n}, k={k}
  Expected: total={exp_total}, g={exp_g}
  Got: total={total}, g={g}")
        await RisingEdge(dut.clk)  # Clear done
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")