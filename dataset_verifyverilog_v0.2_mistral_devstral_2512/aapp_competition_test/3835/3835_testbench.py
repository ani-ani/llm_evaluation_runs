import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math

# Helper function to convert float to Q16.16
def to_q16_16(val):
    return int(val * 65536)

# Helper function to convert Q16.16 to float
def from_q16_16(val):
    if val >= 0x80000000:
        val -= 0x100000000
    return val / 65536.0

@cocotb.test()
async def test_array_restorer(dut):
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test Case 1: Example from problem
    # n=5
    # 0 4 6 2 4
    # 4 0 6 2 4
    # 6 6 0 3 6
    # 2 2 3 0 2
    # 4 4 6 2 0
    # Expected output: 2 2 3 1 2
    
    n = 5
    M = [
        [0, 4, 6, 2, 4],
        [4, 0, 6, 2, 4],
        [6, 6, 0, 3, 6],
        [2, 2, 3, 0, 2],
        [4, 4, 6, 2, 0]
    ]
    expected = [2, 2, 3, 1, 2]

    # Load inputs
    dut.n.value = n
    for i in range(8):
        for j in range(8):
            if i < n and j < n:
                dut.M[i][j].value = to_q16_16(M[i][j])
            else:
                dut.M[i][j].value = 0

    # Wait for combinational logic or pipeline delay
    await Timer(50, units='ns')
    
    # Check results
    for i in range(n):
        dut._log.info(f"Checking index {i}")
        res_val = dut.result[i].value
        # Convert from binary value (handling signedness if any, though values are unsigned)
        if res_val >= (1 << 31):
            res_val = res_val - (1 << 32)
        res_float = res_val / 65536.0
        
        # Compare with expected, allowing small floating point error
        assert abs(res_float - expected[i]) < 0.1, f"Mismatch at {i}: got {res_float}, expected {expected[i]}"

    # Test Case 2: Large numbers (n=3)
    # 0 99990000 99970002
    # 99990000 0 99980000
    # 99970002 99980000 0
    # Expected: 9999 10000 9998
    
    n = 3
    M = [
        [0, 99990000, 99970002],
        [99990000, 0, 99980000],
        [99970002, 99980000, 0]
    ]
    expected = [9999, 10000, 9998]

    dut.n.value = n
    for i in range(8):
        for j in range(8):
            if i < n and j < n:
                dut.M[i][j].value = to_q16_16(M[i][j])
            else:
                dut.M[i][j].value = 0

    await Timer(50, units='ns')

    for i in range(n):
        res_val = dut.result[i].value
        if res_val >= (1 << 31):
            res_val = res_val - (1 << 32)
        res_float = res_val / 65536.0
        assert abs(res_float - expected[i]) < 0.1, f"Mismatch at {i}: got {res_float}, expected {expected[i]}"

    # Test Case 3: Small numbers (n=3)
    # 0 4 4
    # 4 0 4
    # 4 4 0
    # Expected: 2 2 2
    
    n = 3
    M = [
        [0, 4, 4],
        [4, 0, 4],
        [4, 4, 0]
    ]
    expected = [2, 2, 2]

    dut.n.value = n
    for i in range(8):
        for j in range(8):
            if i < n and j < n:
                dut.M[i][j].value = to_q16_16(M[i][j])
            else:
                dut.M[i][j].value = 0

    await Timer(50, units='ns')

    for i in range(n):
        res_val = dut.result[i].value
        if res_val >= (1 << 31):
            res_val = res_val - (1 << 32)
        res_float = res_val / 65536.0
        assert abs(res_float - expected[i]) < 0.1, f"Mismatch at {i}: got {res_float}, expected {expected[i]}"

    dut._log.info("All tests passed")
