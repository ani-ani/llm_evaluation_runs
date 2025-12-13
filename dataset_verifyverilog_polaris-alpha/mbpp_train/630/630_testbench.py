import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestSuccess

@cocotb.test()
async def test_adjacent(dut):
    test_cases = [
        ((3,4), [(2,3),(2,4),(2,5),(3,3),(3,4),(3,5),(4,3),(4,4),(4,5)]),
        ((4,5), [(3,4),(3,5),(3,6),(4,4),(4,5),(4,6),(5,4),(5,5),(5,6)]),
        ((5,6), [(4,5),(4,6),(4,7),(5,5),(5,6),(5,7),(6,5),(6,6),(6,7)]),
        ((0,0), [(0,0),(0,1),(0,0),(0,0),(0,1),(0,0),(1,0),(1,1),(1,0)]),
        ((15,15), [(14,14),(14,15),(14,15),(15,14),(15,15),(15,15),(15,14),(15,15),(15,15)])
    ]
    
    passed = 0
    for (x,y), expected in test_cases:
        dut.x.value = x
        dut.y.value = y
        await Timer(1, units='ns')
        
        errors = []
        for i, (exp_x, exp_y) in enumerate(expected):
            out_val = dut.out.value[i*8+8:i*8].integer
            actual_x = out_val >> 4
            actual_y = out_val & 0xF
            
            if not (actual_x == exp_x and actual_y == exp_y):
                errors.append(f"index {i}: got ({actual_x},{actual_y}), expected ({exp_x},{exp_y})")
        
        if not errors:
            passed += 1
            dut._log.info(f"PASS: {x},{y}")
        else:
            dut._log.error(f"FAIL: {x},{y}
{'
'.join(errors)}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Failed {total-passed}/{total} tests")
    else:
        raise TestSuccess("All tests passed")