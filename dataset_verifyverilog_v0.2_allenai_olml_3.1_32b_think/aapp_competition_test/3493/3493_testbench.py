import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def create_adjacency_matrix(pattern):
    """Convert string pattern to 8x8 binary matrix, first n rows/cols valid"""
    lines = pattern.strip().split('
')
    n = len(lines)
    matrix = [[0]*8 for _ in range(8)]
    for i in range(n):
        for j in range(n):
            if lines[i][j] == 'Y':
                matrix[i][j] = 1
    return matrix, n

def encode_matrix(matrix, n):
    """Flatten matrix to list of (row, col, value) inputs"""
    inputs = []
    for i in range(n):
        for j in range(n):
            inputs.append({'row': i, 'col': j, 'val': matrix[i][j]})
    return inputs

def find_max_matchings_python(matrix, n):
    """Python reference: find max disjoint perfect matchings"""
    from itertools import permutations
    
    # Check if a permutation is valid for current matrix
    def is_valid_matching(perm):
        for btn, person in enumerate(perm):
            if matrix[person][btn] == 0:
                return False
        return True
    
    # Get all possible valid matchings
    all_matchings = []
    for perm in permutations(range(n)):
        if is_valid_matching(perm):
            all_matchings.append(list(perm))
    
    if not all_matchings:
        return 0, []
    
    # Find max disjoint matchings using greedy approach
    used_edges = set()
    result = []
    
    for matching in all_matchings:
        # Check if disjoint from used edges
        disjoint = True
        for btn, person in enumerate(matching):
            if (person, btn) in used_edges:
                disjoint = False
                break
        
        if disjoint:
            result.append(matching)
            for btn, person in enumerate(matching):
                used_edges.add((person, btn))
    
    return len(result), result

@cocotb.test()
async def test_max_bipartite_matching(dut):
    """Test max bipartite matching with 8x8 matrix"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.edge_value.value = 0
    dut.row_idx.value = 0
    dut.col_idx.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            "name": "Sample 1: 3x3 with 2 matchings",
            "pattern": "YYY
NYY
YNY",
            "expected_matchings": 2,
            "expected_outputs": [
                [1, 2, 3],
                [3, 1, 2]
            ]
        },
        {
            "name": "Sample 2: 2x2 no perfect matching",
            "pattern": "YN
YN",
            "expected_matchings": 0,
            "expected_outputs": []
        },
        {
            "name": "Test 3: 3x3 with 3 matchings",
            "pattern": "YYY
YYY
YYY",
            "expected_matchings": 3,
            "expected_outputs": [
                [1, 2, 3],
                [2, 3, 1],
                [3, 1, 2]
            ]
        },
        {
            "name": "Test 4: 4x4 dense",
            "pattern": "YYYY
YYYY
YYYY
YYYY",
            "expected_matchings": 4,
            "expected_outputs": None  # Exact output not critical, just count
        },
        {
            "name": "Test 5: 5x5 cycle",
            "pattern": "YNNNN
NYNNN
NNYNN
NNNYN
NNNNY",
            "expected_matchings": 1,
            "expected_outputs": [[1, 2, 3, 4, 5]]
        }
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    for test in test_cases:
        print(f"
=== {test['name']} ===")
        
        matrix, n = create_adjacency_matrix(test['pattern'])
        print(f"Matrix size: {n}x{n}")
        for row in matrix[:n]:
            print(f"  {''.join(['Y' if x else 'N' for x in row[:n]])}")
        
        # Get reference result
        ref_count, ref_matchings = find_max_matchings_python(matrix, n)
        print(f"Python reference: {ref_count} matchings")
        
        # Load matrix into DUT
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        matrix_inputs = encode_matrix(matrix, n)
        for inp in matrix_inputs:
            dut.row_idx.value = inp['row']
            dut.col_idx.value = inp['col']
            dut.edge_value.value = inp['val']
            dut.valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.valid.value = 0
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for done
        timeout = 10000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done signal in {test['name']}")
        
        # Get result
        actual_matchings = int(dut.num_matchings.value)
        print(f"DUT result: {actual_matchings} matchings")
        
        if actual_matchings != ref_count:
            print(f"FAILED: Expected {ref_count}, got {actual_matchings}")
            continue
        
        if actual_matchings > 0:
            # Read output matchings
            dut_output = []
            for i in range(actual_matchings):
                # Wait for output_valid
                for _ in range(100):
                    if dut.output_valid.value == 1:
                        break
                    await RisingEdge(dut.clk)
                
                matching = []
                for j in range(8):
                    val = int(dut.matching_indices[j].value)
                    if j < n:
                        matching.append(val)
                dut_output.append(matching)
                await RisingEdge(dut.clk)
            
            print(f"DUT output: {dut_output}")
            print(f"Expected: {ref_matchings}")
            
            # Verify each matching is valid
            valid_output = True
            used_pairs = set()
            for matching in dut_output:
                # Check it's a valid permutation for the matrix
                if len(matching) != n:
                    valid_output = False
                    break
                
                seen = set()
                for btn_idx, person in enumerate(matching):
                    if person < 1 or person > n:
                        valid_output = False
                        break
                    person_idx = person - 1
                    if matrix[person_idx][btn_idx] == 0:
                        valid_output = False
                        break
                    if (person_idx, btn_idx) in used_pairs:
                        valid_output = False
                        break
                    if person_idx in seen:
                        valid_output = False
                        break
                    seen.add(person_idx)
                    used_pairs.add((person_idx, btn_idx))
                
                if not valid_output:
                    break
            
            if valid_output:
                passed_tests += 1
                print(f"PASSED: {test['name']}")
            else:
                print(f"FAILED: Invalid matching output")
        else:
            passed_tests += 1
            print(f"PASSED: {test['name']}")
    
    print(f"
=== SUMMARY: {passed_tests}/{total_tests} tests passed ===")
    if passed_tests != total_tests:
        raise TestFailure(f"Only {passed_tests}/{total_tests} tests passed")
