import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fib_seq_solver(dut):
    test_cases = [
        (3, 1, 1, 2, 1),
        (5, 1, 2, 19, 5),
        (1000, 1, 1000, 4417573500000000001, 1573500000000000000),
        (999999, 1, 1, 4417573500000000001, 4417573500000000000),
    ]
    
    passed = 0
    failed = 0
    
    for n_val, a_val, d_val, exp_b, exp_e in test_cases:
        dut.n.value = n_val
        dut.a.value = a_val
        dut.d.value = d_val
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.b.value) or not is_value_defined(dut.e.value):
            cocotb.log.error(f"Test ({n_val},{a_val},{d_val}) failed: Output undefined")
            failed += 1
            continue
        
        b_val = int(dut.b.value)
        e_val = int(dut.e.value)
        
        if b_val == exp_b and e_val == exp_e:
            cocotb.log.info(f"Test ({n_val},{a_val},{d_val}) PASSED")
            passed += 1
        else:
            cocotb.log.error(f"Test ({n_val},{a_val},{d_val}) FAILED: Expected (b={exp_b}, e={exp_e}), Got (b={b_val}, e={e_val})")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{len(test_cases)} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")