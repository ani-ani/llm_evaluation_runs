import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_employee_selector(dut):
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_k = has_signal(dut, 'k')
    has_lambda = has_signal(dut, 'lambda')
    has_s = [has_signal(dut, f's_{i}') for i in range(1,5)]
    has_p = [has_signal(dut, f'p_{i}') for i in range(1,5)]
    has_r = [has_signal(dut, f'r_{i}') for i in range(1,5)]
    has_result = has_signal(dut, 'result')
    has_done = has_signal(dut, 'done')
    
    if not all([has_clk, has_rst, has_start, has_k, has_lambda, has_result, has_done]):
        cocotb.log.error("Missing required signals!")
        return
    if not all(has_s + has_p + has_r):
        cocotb.log.error("Missing employee signals!")
        return
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    def assign_employees(employees):
        for i, (s, p, r) in enumerate(employees, start=1):
            getattr(dut, f's_{i}').value = s
            getattr(dut, f'p_{i}').value = p
            getattr(dut, f'r_{i}').value = r
    
    def compute_expected(k, employees, lambda_float):
        lambda_int = int(round(lambda_float * (1 << 16)))
        best = - (1 << 60)
        for mask in range(1, 16):
            if bin(mask).count('1') != k:
                continue
            valid = True
            total = 0
            for i in range(4):
                if mask & (1 << i):
                    s, p, r = employees[i]
                    if r > 0 and not (mask & (1 << (r-1))):
                        valid = False
                        break
                    term = (p << 16) - (lambda_int * s)
                    total += term
            if valid and total > best:
                best = total
        return best
    
    random.seed(12345)
    test_count = 5
    
    for test_idx in range(test_count):
        cocotb.log.info(f"--- Test case {test_idx+1} ---")
        k = random.randint(1, 4)
        employees = []
        for i in range(4):
            s = random.randint(1, 100)
            p = random.randint(1, 100)
            r = random.randint(0, i)
            employees.append((s, p, r))
        lambda_float = random.uniform(0.0, 10.0)
        
        assign_employees(employees)
        dut.k.value = k
        getattr(dut, 'lambda').value = int(round(lambda_float * (1 << 16)))
        
        expected = compute_expected(k, employees, lambda_float)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        cycles = 0
        while True:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            cycles += 1
            if cycles > 50:
                raise TestFailure("Timeout waiting for done")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Mismatch: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result} (expected {expected})")
        await Timer(100, units='ns')
    
    cocotb.log.info(f"All {test_count} tests passed!")
