import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_noprofit(dut):
    test_cases = [
        (1500, 1200, False),
        (100, 100, True),
        (2000, 5000, False),
        (0, 0, True),
        (65535, 65535, True)
    ]
    passed = 0
    
    for cost, sale, expected in test_cases:
        dut.actual_cost.value = cost
        dut.sale_amount.value = sale
        await Timer(1, units='ns')
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {cost} vs {sale} => {expected}")
        else:
            dut._log.error(f"FAIL: {cost} vs {sale} => {dut.result.value}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")