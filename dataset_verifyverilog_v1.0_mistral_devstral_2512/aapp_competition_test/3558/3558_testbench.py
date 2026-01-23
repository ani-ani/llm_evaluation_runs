import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tv_coverage(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {'N': 3, 'D': 10, 'transmitter_flags': 0b00000001, 'X': [2, 4, 8], 'H': [6, 3, 2], 'expected': 6.0},
        {'N': 5, 'D': 15, 'transmitter_flags': 0b00000110, 'X': [4, 5, 6, 9, 10], 'H': [3, 5, 6, 2, 3], 'expected': 8.5}
    ]
    
    for test in test_cases:
        dut.N.value = test['N']
        dut.D.value = test['D']
        dut.transmitter_flags.value = test['transmitter_flags']
        for i in range(8):
            if i < test['N']:
                dut.X[i].value = test['X'][i]
                dut.H[i].value = test['H'][i]
            else:
                dut.X[i].value = 0
                dut.H[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 10000:
                raise TestFailure("Timeout waiting for done")
        
        if not is_value_defined(dut.covered_length.value):
            raise TestFailure("covered_length is undefined")
        
        result = float(dut.covered_length.value)
        if abs(result - test['expected']) > 1e-3:
            raise TestFailure(f"Test failed: expected {test['expected']}, got {result}")
        
        dut._log.info(f"Test passed: covered_length = {result}")