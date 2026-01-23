import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper to convert float to Q16.16
def to_q16_16(val):
    return int(val * 65536)

# Helper to convert Q16.16 to float
def from_q16_16(val):
    return val / 65536.0

@cocotb.test()
async def test_prime_minister_happiness(dut):
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input 1
    # 3 3
    # 0 4 4
    # 1 5 1
    # 2 6 1
    # Expected: 1.414
    dut.N.value = 3
    dut.K.value = 3
    
    # Coordinates and residents
    dut.x[0].value = 0; dut.y[0].value = 4; dut.residents[0].value = 4
    dut.x[1].value = 1; dut.y[1].value = 5; dut.residents[1].value = 1
    dut.x[2].value = 2; dut.y[2].value = 6; dut.residents[2].value = 1
    
    # Fill rest with dummy data
    for i in range(3, 12):
        dut.x[i].value = 0; dut.y[i].value = 0; dut.residents[i].value = 0

    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Test 1: Timeout - Done not asserted"
    result_q16 = int(dut.min_D.value)
    result_float = from_q16_16(result_q16)
    expected = 1.414
    
    print(f"Test 1 Result: {result_float:.4f} (Q16: {result_q16})")
    assert abs(result_float - expected) < 0.01, f"Test 1 Failed: Expected {expected}, got {result_float}"

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Sample Input 2
    # 6 11
    # 0 0 1
    # 0 1 2
    # 1 0 3
    # 1 1 4
    # 5 5 1
    # 20 20 10
    # Expected: 5.657
    dut.N.value = 6
    dut.K.value = 11
    
    dut.x[0].value = 0; dut.y[0].value = 0; dut.residents[0].value = 1
    dut.x[1].value = 0; dut.y[1].value = 1; dut.residents[1].value = 2
    dut.x[2].value = 1; dut.y[2].value = 0; dut.residents[2].value = 3
    dut.x[3].value = 1; dut.y[3].value = 1; dut.residents[3].value = 4
    dut.x[4].value = 5; dut.y[4].value = 5; dut.residents[4].value = 1
    dut.x[5].value = 20; dut.y[5].value = 20; dut.residents[5].value = 10
    
    for i in range(6, 12):
        dut.x[i].value = 0; dut.y[i].value = 0; dut.residents[i].value = 0

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while dut.done.value == 0 and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Test 2: Timeout"
    result_q16 = int(dut.min_D.value)
    result_float = from_q16_16(result_q16)
    expected = 5.657
    
    print(f"Test 2 Result: {result_float:.4f}")
    assert abs(result_float - expected) < 0.01, f"Test 2 Failed: Expected {expected}, got {result_float}"

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 3: Sample Input 3
    # 6 5
    # 20 20 9
    # 0 0 3
    # 0 1 1
    # 10 0 1
    # 10 1 6
    # 12 0 3
    # Expected: 2.000
    dut.N.value = 6
    dut.K.value = 5
    
    dut.x[0].value = 20; dut.y[0].value = 20; dut.residents[0].value = 9
    dut.x[1].value = 0; dut.y[1].value = 0; dut.residents[1].value = 3
    dut.x[2].value = 0; dut.y[2].value = 1; dut.residents[2].value = 1
    dut.x[3].value = 10; dut.y[3].value = 0; dut.residents[3].value = 1
    dut.x[4].value = 10; dut.y[4].value = 1; dut.residents[4].value = 6
    dut.x[5].value = 12; dut.y[5].value = 0; dut.residents[5].value = 3
    
    for i in range(6, 12):
        dut.x[i].value = 0; dut.y[i].value = 0; dut.residents[i].value = 0

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while dut.done.value == 0 and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1

    assert dut.done.value == 1, "Test 3: Timeout"
    result_q16 = int(dut.min_D.value)
    result_float = from_q16_16(result_q16)
    expected = 2.000
    
    print(f"Test 3 Result: {result_float:.4f}")
    assert abs(result_float - expected) < 0.01, f"Test 3 Failed: Expected {expected}, got {result_float}"

    print("All tests passed!")
