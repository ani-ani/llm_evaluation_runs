import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

# Helper to generate test vectors
def p_vector(arr, n):
    r = 0
    for i,v in enumerate(arr):
        if i >= n:
            break
        r |= ((v-1) & 0x7) << (3*i)
    return r

async def reset_dut(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.q.value = 0
    dut.s.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_perm_checker(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    test_cases = [
        (4, 1, [2,3,4,1], [1,2,3,4], False),   # Original: NO
        (4, 1, [4,3,1,2], [3,4,2,1], True),   # Original: YES
        (4, 3, [4,3,1,2], [3,4,2,1], True),   # Original: YES
        (3, 3, [2,3,1], [2,3,1], True),       # Scenario from n=3 case
        (2, 99, [2,1], [2,1], False)           # k>16 - scale to k=16
    ]
    
    passed = 0
    for tnum, (n_val, k_val, q_arr, s_arr, expected) in enumerate(test_cases):
        if n_val > 8:
            continue  # Skip cases with n>8
        if k_val > 16:
            k_val = 16  # Cap k at 16
            expected = False  # Original test has k=99 > 16
        
        dut.n.value = n_val
        dut.k.value = k_val
        dut.q.value = p_vector(q_arr, n_val)
        dut.s.value = p_vector(s_arr, n_val)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 20
        while (not dut.done.value) and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error(f"Test {tnum} timed out")
        elif dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test {tnum} failed: got {dut.result.value}, expected {expected}
            q={q_arr}, s={s_arr}, n={n_val}, k={k_val}")
        
        await reset_dut(dut)
    
    total_tests = len([tc for tc in test_cases if tc[0] <= 8 and tc[1] <=16])
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests