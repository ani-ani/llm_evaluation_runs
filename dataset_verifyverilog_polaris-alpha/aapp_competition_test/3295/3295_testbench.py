import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

# Helper function to check prime (Python behavior)
def is_prime(n):
    if n <= 1:
        return False
    for i in range(2, int(math.isqrt(n)) + 1):
        if n % i == 0:
            return False
    return True

@cocotb.test()
async def test_mirko_solver(dut):
    # Generate clock (100 MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset sequence
    dut.rst_n.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await Timer(10, units="ns")

    # Test cases: (K, L, M, expected_output)
    test_cases = [
        (1, 1, 1, 1),
        (2, 0, 2, 8),
        (3, 1, 1, 4),
        (4, 1, 1, 6),
        (5, 2, 3, 4),
        (5, 0, 3, 24)
    ]
    passed = 0

    for K, L, M, expected in test_cases:
        # Apply inputs
        dut.start.value = 0
        dut.K.value = K
        dut.L.value = L
        dut.M.value = M
        await RisingEdge(dut.clk)
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait until done asserted
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check result
        result = dut.result.value.signed_integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: K={K}, L={L}, M={M} => {result} (expected {expected})")
        # Reset for next test
        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
