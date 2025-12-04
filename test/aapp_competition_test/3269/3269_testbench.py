import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_digit_distance(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        dut.A.value = 0
        dut.B.value = 0
        await RisingEdge(dut.clk)
    
    # Convert number to 4-digit BCD format (4 bits per digit)
    def to_bcd(num):
        digits = []
        for _ in range(4):
            digits.append(num % 10)
            num //= 10
        return sum(digit << (4*i) for i, digit in enumerate(digits))
    
    # Python reference implementation
    def calc_distance_sum(A, B, mod):
        total = 0
        for x in range(A, B+1):
            for y in range(A, x+1):
                sx = f"{x:04d}"
                sy = f"{y:04d}"
                d = sum(abs(int(a) - int(b)) for a,b in zip(sx, sy))
                total += d * (2 if x != y else 1)
        return total % mod
    
    test_cases = [
        (1, 5, 40),
        (288, 291, 76),
        (0, 0, 0),          # edge case: single number
        (9995, 9999, 1080)  # edge case: large distance
    ]
    
    await reset()
    passed = 0
    mod = 1000000007
    
    for (A_val, B_val, expected) in test_cases:
        dut._log.info(f"Testing {A_val} to {B_val}")
        dut.A.value = to_bcd(A_val)
        dut.B.value = to_bcd(B_val)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout after 1M cycles)
        timeout = 1000000
        while not int(dut.done.value) and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Timeout waiting for done")
            continue
        
        result = dut.result.value.integer % mod
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Failed {A_val}-{B_val}: got {result}, expected {expected}")
        
        await reset()
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)