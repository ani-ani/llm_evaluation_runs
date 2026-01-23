import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_prod_signs(dut):
    """Test prod_signs module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr_len.value = 0
    for i in range(8):
        setattr(dut, f'arr_data_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (arr_len, [data_0..data_7], expected_result)
        (4, [1, 2, 2, -4, 0, 0, 0, 0], -9),
        (2, [0, 1, 0, 0, 0, 0, 0, 0], 0),
        (0, [0, 0, 0, 0, 0, 0, 0, 0], 0),
        (7, [1, 1, 1, 2, 3, -1, 1, 0], -10),
        (7, [2, 4, 1, 2, -1, -1, 9, 0], 20),
        (4, [-1, 1, -1, 1, 0, 0, 0, 0], 4),
        (4, [-1, 1, 1, 1, 0, 0, 0, 0], -4),
        (4, [-1, 1, 1, 0, 0, 0, 0, 0], 0),
        # Edge cases
        (1, [5, 0, 0, 0, 0, 0, 0, 0], 5),
        (1, [-5, 0, 0, 0, 0, 0, 0, 0], -5),
        (1, [0, 0, 0, 0, 0, 0, 0, 0], 0),
        (8, [1, 2, 3, 4, 5, 6, 7, 8], 36),
        (8, [-1, -2, -3, -4, -5, -6, -7, -8], -36),
        (5, [10, -10, 5, -5, 0, 0, 0, 0], 0),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr_len, data, expected in test_cases:
        # Setup inputs
        dut.arr_len.value = arr_len
        for i in range(8):
            val = data[i] if i < len(data) else 0
            val = val & 0xFF if val >= 0 else (val + 256) & 0xFF
            getattr(dut, f'arr_data_{i}').value = val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.valid.value == 1:
                break
        
        # Check result
        actual = dut.result.value
        if actual >= (1 << 31):
            actual = actual - (1 << 32)
        
        if dut.valid.value == 1 and actual == expected:
            passed += 1
            print(f"PASS: arr_len={arr_len}, result={actual}, expected={expected}")
        else:
            print(f"FAIL: arr_len={arr_len}, result={actual}, expected={expected}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
