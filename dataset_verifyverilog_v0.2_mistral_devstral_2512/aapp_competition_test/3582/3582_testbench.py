import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def is_valid_cycle(assignment, n):
    """Check if assignment forms a single cycle covering all employees 1..n"""
    visited = set()
    start = 1
    current = start
    count = 0
    while True:
        if current in visited:
            return False
        visited.add(current)
        count += 1
        if count > n:
            return False
        next_emp = assignment[current-1]  # convert to 0-indexed
        if next_emp == 0:
            return False
        if next_emp == start and count == n:
            return True
        if next_emp == start and count < n:
            return False
        if count > n:
            return False
        current = next_emp

def evaluate_assignment(new_assign, orig_assign, n):
    """Evaluate quality: lower is better. Returns (primary_score, secondary_score)"""
    changes = []
    for i in range(n):
        emp = i + 1
        if new_assign[i] != orig_assign[i]:
            changes.append((emp, new_assign[i]))
    if not changes:
        return (0, 0)  # perfect, no changes
    # First different employee (lowest index where they differ)
    first_diff = changes[0][0]
    new_mentor = changes[0][1]
    # Prefer keeping original mentor -> if we reach here, original was changed
    # So we want to minimize the new mentor number
    return (first_diff, new_mentor)

def find_best_assignment_brute(n, current):
    """Brute force find best valid cycle assignment for small n"""
    import itertools
    
    # Generate all permutations of mentors for employees 1..n
    # But each employee's mentor must be in 1..n, not themselves
    employees = list(range(1, n+1))
    best_assignment = None
    best_score = (float('inf'), float('inf'))
    
    # We need to assign to each employee a mentor, forming a permutation
    # This means we need to assign n mentors to n employees
    # We can represent as permutation of employees
    
    for perm in itertools.permutations(employees):
        # perm[i] = mentor of employee (i+1)
        # Check constraint: no self-mentorship
        valid = True
        for i in range(n):
            if perm[i] == i + 1:
                valid = False
                break
        if not valid:
            continue
            
        # Check if it forms one cycle
        if not is_valid_cycle(list(perm), n):
            continue
            
        # Evaluate
        score = evaluate_assignment(list(perm), current, n)
        if score < best_score:
            best_score = score
            best_assignment = list(perm)
    
    return best_assignment

@cocotb.test()
async def test_gaggle_mentor(dut):
    """Test the gaggle_mentor module with various cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.current_mentor[i].value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {
            "n": 4,
            "current": [2, 1, 4, 3],
            "expected": [2, 3, 4, 1]
        },
        {
            "n": 3,
            "current": [3, 3, 1],
            "expected": [3, 1, 2]
        },
        {
            "n": 2,
            "current": [2, 1],
            "expected": [2, 1]  # already a valid cycle
        },
        {
            "n": 3,
            "current": [2, 3, 1],
            "expected": [2, 3, 1]  # already a valid cycle
        },
        {
            "n": 4,
            "current": [2, 3, 4, 1],
            "expected": [2, 3, 4, 1]  # already a valid cycle
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        n = test["n"]
        current = test["current"]
        expected = test["expected"]
        
        # Verify expected is indeed valid
        if not is_valid_cycle(expected, n):
            print(f"Test {i+1}: Skipping - expected is invalid")
            total -= 1
            continue
        
        # Set inputs
        dut.n.value = n
        for j in range(8):
            if j < n:
                dut.current_mentor[j].value = current[j]
            else:
                dut.current_mentor[j].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read results
        # The module should output each employee's new mentor one by one
        # We need to collect all outputs
        result = [0] * n
        
        for emp_idx in range(n):
            # Module should indicate which employee it's outputting
            # and provide the new mentor
            await RisingEdge(dut.clk)
            idx = int(dut.employee_idx.value)
            mentor = int(dut.new_mentor.value)
            if 0 <= idx < n:
                result[idx] = mentor
        
        # Validate result
        if not is_valid_cycle(result, n):
            raise TestFailure(f"Test {i+1}: Result {result} is not a valid cycle")
        
        if result == expected:
            passed += 1
            print(f"Test {i+1}: PASSED")
        else:
            print(f"Test {i+1}: FAILED")
            print(f"  Input: n={n}, current={current}")
            print(f"  Expected: {expected}")
            print(f"  Got: {result}")
            print(f"  Note: May need to verify if result is actually better than expected")
            # Check if our result is actually better (maybe expected wasn't optimal)
            brute_best = find_best_assignment_brute(n, current)
            if result == brute_best:
                passed += 1
                print(f"  Result matches brute-force optimal!")
            else:
                print(f"  Brute-force optimal: {brute_best}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
