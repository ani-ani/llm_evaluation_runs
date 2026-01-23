import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import itertools

def parse_program(tokens):
    """Flatten program tokens into sequence of variable indices."""
    def parse(idx):
        seq = []
        while idx < len(tokens):
            token = tokens[idx]
            if token == 'E':
                return seq, idx + 1
            elif token.startswith('R'):
                n = int(token[1:])
                subseq, next_idx = parse(idx + 1)
                seq.extend(subseq * n)
                idx = next_idx
            elif token.startswith('V'):
                var_idx = int(token[1:])
                seq.append(var_idx)
                idx += 1
        return seq, idx
    seq, _ = parse(0)
    return seq

def get_all_assignments(variables, num_banks):
    """Generate all possible bank assignments for given variables."""
    return list(itertools.product(range(num_banks), repeat=len(variables)))

@cocotb.test()
async def test_optimize_harvard(dut):
    """Test multiple programs to verify correct minimum cost calculation."""
    
    # Test cases: (b, s, program_str, expected_output)
    test_cases = [
        (1, 2, "V1 V2 V1 V1 V2", 5),
        (2, 1, "V1 V2 V1 V1 V2", 6),
        (1, 2, "R10 V1 V2 V1 E", 30),
        (4, 1, "V1 R2 V2 V4 R2 V1 E V3 E", 17),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_idx, (b, s, program_str, expected) in enumerate(test_cases):
        # Parse program into tokens
        tokens = program_str.split()
        
        # Flatten to sequence
        flat_seq = parse_program(tokens)
        
        # Get unique variables
        unique_vars = sorted(set(flat_seq))
        num_vars = len(unique_vars)
        
        # Limit for hardware: max 8 variables
        if num_vars > 8:
            print(f"Test {test_idx+1}: Too many variables ({num_vars}), skipping")
            continue
        
        # Generate all assignments
        assignments = get_all_assignments(unique_vars, b)
        
        # Prepare program array (pad to 32 elements)
        program_array = [0] * 32
        for i, var in enumerate(flat_seq):
            if i < 32:
                program_array[i] = var
        
        # Set program_length
        dut.program_length.value = len(flat_seq)
        
        # Set b
        dut.b.value = b
        
        # Set program array
        for i in range(32):
            dut.program[i].value = program_array[i]
        
        # Try all assignments, track minimum
        min_cost = float('inf')
        
        for assign_tuple in assignments:
            # Create mapping from variable to bank
            # assign_tuple gives bank for each variable in unique_vars
            var_to_bank = {var: bank for var, bank in zip(unique_vars, assign_tuple)}
            
            # Fill bank_assignment array (0 unused, 1-13 used)
            bank_assign_array = [0] * 14
            for var in range(1, 14):
                if var in var_to_bank:
                    bank_assign_array[var] = var_to_bank[var]
                else:
                    bank_assign_array[var] = 0  # unused
            
            # Set bank_assignment inputs
            for i in range(14):
                dut.bank_assignment[i].value = bank_assign_array[i]
            
            # Wait for combinational logic to settle
            await Timer(1, units='ns')
            
            # Read cost
            cost = dut.total_cost.value
            if cost < min_cost:
                min_cost = cost
        
        # Verify
        if min_cost == expected:
            print(f"Test {test_idx+1} PASSED: {program_str} -> {min_cost}")
            passed += 1
        else:
            print(f"Test {test_idx+1} FAILED: {program_str} -> Expected {expected}, Got {min_cost}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} of {total} tests passed"
