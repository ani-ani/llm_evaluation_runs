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

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def compute_max_satisfied(people):
    n = len(people)
    best = 0
    for mask in range(1 << n):
        max_a = 0
        max_b = 0
        max_c = 0
        for i in range(n):
            if mask & (1 << i):
                a, b, c = people[i]
                if a > max_a: max_a = a
                if b > max_b: max_b = b
                if c > max_c: max_c = c
        if max_a + max_b + max_c <= 10000:
            cnt = bin(mask).count('1')
            if cnt > best:
                best = cnt
    return best

def generate_test_case(num_people=8):
    people = []
    for _ in range(num_people):
        total = random.randint(0, 10000)
        a = random.randint(0, total)
        total_b = total - a
        b = random.randint(0, total_b)
        c = total_b - b
        people.append((a, b, c))
    expected = compute_max_satisfied(people)
    return people, expected

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_satisfied_people(dut):
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure("DUT must be sequential with clk and done signals")
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = []
    people1 = [(10000,0,0), (0,10000,0), (0,0,10000)]
    test_cases.append((people1, 1, "Sample case 1"))
    people2 = [(5000,0,0), (0,2000,0), (0,0,4000)]
    test_cases.append((people2, 2, "Sample case 2"))
    
    for i in range(3):
        people, expected = generate_test_case(8)
        test_cases.append((people, expected, f"Random case {i+1}"))
    
    passed = 0
    failed = 0
    
    for idx, (people, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: {description}")
        
        for i, (a, b, c) in enumerate(people):
            getattr(dut, f'a{i}').value = a
            getattr(dut, f'b{i}').value = b
            getattr(dut, f'c{i}').value = c
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done in test {idx+1}")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined in test {idx+1}")
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"Test {idx+1} failed: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {idx+1} passed")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")