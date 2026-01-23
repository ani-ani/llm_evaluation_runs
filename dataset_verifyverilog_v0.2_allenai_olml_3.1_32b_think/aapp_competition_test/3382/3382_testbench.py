import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper to count inversions (grade cost)
def count_inversions(perm):
    inv = 0
    for i in range(len(perm)):
        for j in range(i + 1, len(perm)):
            if perm[i] > perm[j]:
                inv += 1
    return inv * 2

# Helper to evaluate python expression for verification
def evaluate_python(vals, ops, case):
    a, b, c, d = vals
    op1, op2, op3 = ops
    
    try:
        # Define safe operations
        def do_op(x, y, op):
            if op == 0: return x + y
            if op == 1: return x - y
            if op == 2: return x * y
            if op == 3: 
                if y == 0 or x % y != 0: raise ZeroDivisionError
                return x // y
            return 0
        
        if case == 0: # ((a op b) op c) op d
            t1 = do_op(a, b, op1)
            t2 = do_op(t1, c, op2)
            t3 = do_op(t2, d, op3)
            return t3
        elif case == 1: # (a op (b op c)) op d
            t1 = do_op(b, c, op2)
            t2 = do_op(a, t1, op1)
            t3 = do_op(t2, d, op3)
            return t3
        elif case == 2: # a op ((b op c) op d)
            t1 = do_op(b, c, op2)
            t2 = do_op(t1, d, op3)
            t3 = do_op(a, t2, op1)
            return t3
        elif case == 3: # a op (b op (c op d))
            t1 = do_op(c, d, op3)
            t2 = do_op(b, t1, op2)
            t3 = do_op(a, t2, op1)
            return t3
        elif case == 4: # (a op b) op (c op d)
            t1 = do_op(a, b, op1)
            t2 = do_op(c, d, op3)
            t3 = do_op(t1, t2, op2)
            return t3
    except ZeroDivisionError:
        return None
    except:
        return None
    return None

def find_min_grade_py(vals):
    from itertools import permutations, product
    min_g = 100
    found = False
    
    # 5 parenthesis cases
    # Costs: 0, 1, 1, 2, 2
    p_costs = [0, 1, 1, 2, 2]
    
    for perm in permutations(vals):
        inv_cost = count_inversions(list(perm))
        
        for ops in product(range(4), repeat=3):
            for case in range(5):
                res = evaluate_python(list(perm), list(ops), case)
                if res is not None and res == 24:
                    total_grade = inv_cost + p_costs[case]
                    if total_grade < min_g:
                        min_g = total_grade
                        found = True
    return min_g, found

@cocotb.test()
async def test_challenge24(dut):
    # Create clock
    c = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(c.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.val0.value = 0
    dut.val1.value = 0
    dut.val2.value = 0
    dut.val3.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 5 5 2 -> Expected grade 1
    vals = [3, 5, 5, 2]
    dut.val0.value = vals[0]
    dut.val1.value = vals[1]
    dut.val2.value = vals[2]
    dut.val3.value = vals[3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    py_min, py_found = find_min_grade_py(vals)
    hw_grade = int(dut.min_grade.value)
    hw_found = int(dut.found.value)
    
    dut._log.info(f"Test 1: Input {vals}. Python result: {py_min if py_found else 'Impossible'}, HW: {hw_grade if hw_found else 'Impossible'}")
    
    if py_found:
        if not hw_found or hw_grade != py_min:
            raise TestFailure(f"Mismatch: Expected {py_min}, got {hw_grade} (found={hw_found})")
    else:
        if hw_found:
            raise TestFailure(f"Expected Impossible, but got grade {hw_grade}")
            
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 1 1 1 1 -> Expected impossible
    vals = [1, 1, 1, 1]
    dut.val0.value = vals[0]
    dut.val1.value = vals[1]
    dut.val2.value = vals[2]
    dut.val3.value = vals[3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        # Timeout safety
        
    py_min, py_found = find_min_grade_py(vals)
    hw_grade = int(dut.min_grade.value)
    hw_found = int(dut.found.value)
    
    dut._log.info(f"Test 2: Input {vals}. Python result: {py_min if py_found else 'Impossible'}, HW: {hw_grade if hw_found else 'Impossible'}")
    
    if py_found:
        if not hw_found or hw_grade != py_min:
            raise TestFailure(f"Mismatch: Expected {py_min}, got {hw_grade} (found={hw_found})")
    else:
        if hw_found:
            raise TestFailure(f"Expected Impossible, but got grade {hw_grade}")
            
    # Test case 3: 8 3 8 3 -> Expected grade 0 (8*3+8*3 = 24)
    vals = [8, 3, 8, 3]
    dut.val0.value = vals[0]
    dut.val1.value = vals[1]
    dut.val2.value = vals[2]
    dut.val3.value = vals[3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        
    py_min, py_found = find_min_grade_py(vals)
    hw_grade = int(dut.min_grade.value)
    hw_found = int(dut.found.value)
    
    dut._log.info(f"Test 3: Input {vals}. Python result: {py_min if py_found else 'Impossible'}, HW: {hw_grade if hw_found else 'Impossible'}")
    
    if py_found:
        if not hw_found or hw_grade != py_min:
            raise TestFailure(f"Mismatch: Expected {py_min}, got {hw_grade} (found={hw_found})")
    else:
        if hw_found:
            raise TestFailure(f"Expected Impossible, but got grade {hw_grade}")
            
    # Test case 4: 1 2 3 4 -> Known to have solutions
    vals = [1, 2, 3, 4]
    dut.val0.value = vals[0]
    dut.val1.value = vals[1]
    dut.val2.value = vals[2]
    dut.val3.value = vals[3]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        
    py_min, py_found = find_min_grade_py(vals)
    hw_grade = int(dut.min_grade.value)
    hw_found = int(dut.found.value)
    
    dut._log.info(f"Test 4: Input {vals}. Python result: {py_min if py_found else 'Impossible'}, HW: {hw_grade if hw_found else 'Impossible'}")
    
    if py_found:
        if not hw_found or hw_grade != py_min:
            raise TestFailure(f"Mismatch: Expected {py_min}, got {hw_grade} (found={hw_found})")
    else:
        if hw_found:
            raise TestFailure(f"Expected Impossible, but got grade {hw_grade}")
            
    print("All tests passed!")
