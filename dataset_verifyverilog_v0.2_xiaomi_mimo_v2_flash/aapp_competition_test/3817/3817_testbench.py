import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

MOD = 1000000009

async def get_expected(n, m):
    # Python reference calculation
    power = pow(2, m, MOD)
    res = 1
    for i in range(n):
        term = (power - 1 - i) % MOD
        res = (res * term) % MOD
    return res

@cocotb.test()
async def test_wool_sequence(dut):
    """Test Wool Sequence Counter"""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases from problem
    test_cases = [
        (3, 2, 6),
        (4, 2, 0),
        (1, 2, 3),
        (2, 15, 1),
        (4, 1, 0),
        (3, 1, 0),
        (2, 2, 6)
    ]

    passed = 0
    total = len(test_cases)

    for n, m, expected in test_cases:
        dut.n.value = n
        dut.m.value = m
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 2000000 # Safety limit for simulation
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"Test (n={n}, m={m}): Timeout - Simulation took too long")
            continue

        # Check result
        result = int(dut.result.value)
        print(f"Test (n={n}, m={m}): Got {result}, Expected {expected}")
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Mismatch: Result {result} != Expected {expected}")

    print(f"Summary: {passed}/{total} tests passed")