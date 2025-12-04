import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_rebus(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Input1: ? + ? - ? + ? + ? = 42 (simplified to 5 terms)
        {'num_terms':5, 'n':42, 'signs':0b10111, 'exp_possible':1},
        # Input2: ? - ? = 1 (modified for 2 terms)
        {'num_terms':2, 'n':1, 'signs':0b10, 'exp_possible':0},
        # Input3: ? = 1000000 (n scaled to 16-bit)
        {'num_terms':1, 'n':65535, 'signs':0b1, 'exp_possible':1}
    ]
    passed = 0

    for case in test_cases:
        dut.num_terms.value = case['num_terms']
        dut.n.value = case['n']
        dut.sign_pattern.value = case['signs']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.possible.value != case['exp_possible']:
            dut._log.error("Test failed: Expected possible=%d got=%d" % (case['exp_possible'], dut.possible.value))
        else:
            passed += 1
            # Check solution validity if applicable
            if case['exp_possible']:
                sum_val = 0
                for i in range(case['num_terms']):
                    val = dut.solution[i].value.integer
                    sign = 1 if (case['signs'] >> i) & 1 else -1
                    sum_val += sign * val
                    if val < 1 or val > case['n']:
                        dut._log.error("Value %d out of range [1-%d]" % (val, case['n']))
                if sum_val != case['n']:
                    dut._log.error("Sum mismatch: %d != %d" % (sum_val, case['n']))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))