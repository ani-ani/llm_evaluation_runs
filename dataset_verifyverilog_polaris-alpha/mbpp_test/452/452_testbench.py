import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_loss_amount(dut):
    test_cases = [
        (1500, 1200, 0),
        (100, 200, 100),
        (2000, 5000, 3000),
        (0, 0, 0),       # Edge case: equal values
        (32767, -32768, 0) # Edge case: max/min signed
    ]
    passed = 0
    
    for actual, sale, expected in test_cases:
        dut.actual_cost.value = actual
        dut.sale_amount.value = sale
        await Timer(1, units='ns')
        result = dut.loss_amount.value.signed_integer
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Actual={actual}, Sale={sale} => Loss={result}")
        else:
            dut._log.error(f"FAIL: Actual={actual}, Sale={sale} => {result}, expected {expected}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")