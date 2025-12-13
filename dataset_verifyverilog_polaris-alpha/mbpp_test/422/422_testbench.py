import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_average_cubes(dut):
    test_cases = [
        (1, 1.0),
        (2, 4.5),
        (3, 12.0),
        (4, 25.0),
        (15, 960.0)
    ]
    passed = 0
    
    for n_val, expected_float in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        
        # Convert output to float
        hw_value = dut.average_q16_16.value.integer
        actual_float = hw_value / 65536.0
        
        # Check with 0.0001 tolerance for floating point
        if abs(actual_float - expected_float) < 0.0001:
            passed += 1
            dut._log.info(f"PASS: n={n_val} => {actual_float:.6f} (expected {expected_float})")
        else:
            dut._log.error(f"FAIL: n={n_val} => {actual_float:.6f}, expected {expected_float}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")