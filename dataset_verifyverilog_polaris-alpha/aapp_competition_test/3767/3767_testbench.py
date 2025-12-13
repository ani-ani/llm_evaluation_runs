import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from itertools import zip_longest

@cocotb.test()
async def test_soda_pouring(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (n, a_list, b_list, expected_k, expected_t)
    test_cases = [
        # Original scaled-down cases
        (4, [3,3,4,3], [4,7,6,5], 2, 6),
        (2, [1,1], [100,100], 1, 1),
        (1, [50], [100], 1, 0),
        # Edge cases
        (2, [1,1], [1,100], 1, 1),
        (3, [10,20,30], [10,30,40], 2, 30)
    ]

    passed = 0
    for tc in test_cases:
        n, a_vals, b_vals, exp_k, exp_t = tc
        dut.n.value = n - 1  # 0-indexed count
        
        # Load a/b arrays
        for i in range(8):
            dut.a[i].value = a_vals[i] if i < len(a_vals) else 0
            dut.b[i].value = b_vals[i] if i < len(b_vals) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 10 cycles + 1 for output
        for _ in range(11):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.done.value != 1:
            dut._log.error(f"Test didn't complete: {tc}")
        elif dut.k.value == exp_k and dut.t.value == exp_t:
            passed += 1
        else:
            dut._log.error(f"Failed test {tc}: Got ({dut.k.value},{dut.t.value})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")