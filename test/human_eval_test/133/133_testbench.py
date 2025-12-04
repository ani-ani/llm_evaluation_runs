import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import math

def float_to_q16(x):
    return int(x * 65536)

def process_test_case(lst):
    """Python calculation of expected result"""
    ceil_squares = [math.ceil(x)**2 for x in lst]
    return sum(ceil_squares)

@cocotb.test()
async def test_ceil_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Create test cases (first 5 original tests)
    test_cases = [
        {'in': [1.0, 2.0, 3.0], 'exp': process_test_case([1.0,2.0,3.0])},
        {'in': [1.4, 4.2, 0.0], 'exp': process_test_case([1.4,4.2,0])},
        {'in': [-2.4, 1.0, 1.0], 'exp': process_test_case([-2.4,1,1])},
        {'in': [100.0, 1.0, 15.0, 2.0], 'exp': process_test_case([100,1,15,2])},
        {'in': [0.0], 'exp': process_test_case([0])},
        {'in': [-1.4, 4.6, 6.3], 'exp': process_test_case([-1.4,4.6,6.3])}
    ]

    passed = 0
    total = len(test_cases)

    for case in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Reset sequence
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        data_in = [0.0]*8  # pad to 8 elements
        for i,x in enumerate(case['in']):
            data_in[i] = float_to_q16(x)
        
        for i in range(8):
            dut.data_in[i].value = data_in[i]

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal (11 cycles)
        for _ in range(11):
            await RisingEdge(dut.clk)

        if dut.done.value != 1:
            dut._log.error("Done signal not set after 11 cycles")
            continue

        # Check result
        expected = case['exp']
        actual = dut.result.value.signed_integer
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: Input {case['in']} → Got {actual} (expected {expected})")
        else:
            dut._log.error(f"FAIL: Input {case['in']} → Got {actual}, expected {expected}")

        # Wait one cycle before next test
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"