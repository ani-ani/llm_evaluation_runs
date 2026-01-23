import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

MODULO = 1000000007

def calculate_complexity(mask_str):
    """Reference Python implementation"""
    n = len(mask_str)
    ans = 0
    for k in range(n):
        if mask_str[k] == '1':
            # 2^k * 4^(n-k-1)
            term = pow(2, k, MODULO) * pow(4, n - k - 1, MODULO)
            ans = (ans + term) % MODULO
    return ans

@cocotb.test()
def test_dance_complexity(dut):
    """Test dance_complexity module with various inputs"""
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x_mask.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        ("1", 1),
        ("01", 2),
        ("11", 6),
        ("11111111", 178956952), # n=8, all 1s
        ("00000000", 0),
        ("10101010", 1065353216 % MODULO),
        ("11100000", 167772160) # Manual check: k=0->2^0*4^7=16384, k=1->2^1*4^6=8192, k=2->2^2*4^5=4096 => 28672 is for n=5? No. Wait.
    ]

    # Let's generate cases dynamically based on Python reference
    inputs = [
        "1",
        "01",
        "11",
        "101",
        "11111111",
        "00000000",
        "10000001",
        "11010101"
    ]

    passed = 0
    total = len(inputs)

    for mask_str in inputs:
        # Prepare input
        n_val = len(mask_str)
        # Pad to 8 bits for the interface
        mask_bits = int(mask_str, 2)
        
        # Expected result
        expected = calculate_complexity(mask_str)
        
        # Send inputs
        dut.x_mask.value = mask_bits
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 50:
            raise TestFailure(f"Timeout waiting for done for mask {mask_str}")
            
        # Check result
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"Mask {mask_str}: PASS (Result {actual})")
        else:
            dut._log.error(f"Mask {mask_str}: FAIL (Expected {expected}, Got {actual})")
            
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed")
