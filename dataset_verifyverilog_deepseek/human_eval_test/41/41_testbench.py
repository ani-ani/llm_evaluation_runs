import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_car_collision(dut):
    test_cases = [
        (0, 0),
        (1, 1),
        (2, 4),
        (3, 9),
        (4, 16),
        (8, 64),
        (10, 100),
        (16, 256),
        (255, 65025)
    ]
    passed = 0
    
    for n_val, expected in test_cases:
        dut.n.value = n_val
        await Timer(1, units='ns')
        result = dut.collision_count.value
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n_val} got {result}, expected {expected}")
        else:
            dut._log.error(f"FAIL: n={n_val} got {result}, expected {expected}")
    
    dut._log.info(f"Final result: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"