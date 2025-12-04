import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_max_lights(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    test_cases = [
        # Adapted test 1 (original 3 lights)
        {
            'n': 3,
            'init': 0b101,
            'a': 0o333333, # 3,3,3 in octal (each 3-bit: 0b011)
            'b': 0o321000, # 3,2,1 (light0:3, light1:2, light2:1)
            'expected': 2
        },
        # Adapted test 2 (original 4 lights)
        {
            'n': 4,
            'init': 0b1111,
            'a': 0o345434, # [3,5,3,3] (5≡101→5 needs extra bit)
            'b': 0o421224, # [4,2,1,2]
            'expected': 4
        },
        # Adapted test 3 (single light)
        {
            'n': 1,
            'init': 0b0,
            'a': 0o100000, # [1] 
            'b': 0o500000, # [5]
            'expected': 1
        }
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for test in test_cases:
        dut.n.value = test['n']
        dut.init_state.value = test['init']
        dut.a_vals.value = test['a']
        dut.b_vals.value = test['b']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait computation time (25 cycles)
        for _ in range(26):
            await RisingEdge(dut.clk)
        if dut.done.value != 1:
            dut._log.error("Done signal not asserted")
        elif dut.max_on.value == test['expected']:
            passed += 1
        else:
            dut._log.error(f"FAIL: Expected {test['expected']}, got {dut.max_on.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)