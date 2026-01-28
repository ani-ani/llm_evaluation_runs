import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- MANDATORY HELPERS ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# --- GRID PARSER ---
def parse_grid(input_str):
    """
    Parses the input string into flattened arrays.
    Returns (grid_valid_list, grid_constraint_list)
    """
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    
    # Parse rows
    raw_rows = []
    for i in range(1, n + 1):
        raw_rows.append(list(map(int, lines[i].split())))
    
    # Map to 7x7 grid (max size)
    # In hexagonal grid:
    # Odd rows (1, 3, 5...) have n hexagons
    # Even rows (2, 4, 6...) have n-1 hexagons
    # We map this to a 2D coordinate system.
    # Let's use a generic approach for max 7x7.
    
    grid_valid = [0] * 69
    grid_constraint = [0] * 69
    
    idx = 0
    for r in range(7):
        if r >= n:
            break
        
        is_odd = (r + 1) % 2 != 0
        row_len = n if is_odd else n - 1
        
        for c in range(row_len):
            if idx < 69:
                val = raw_rows[r][c]
                if val != -1:
                    grid_valid[idx] = 1
                    grid_constraint[idx] = val
                # If val == -1, valid is 0 (treat as wall/invalid)
            idx += 1
            
    return grid_valid, grid_constraint

@cocotb.test(timeout_time=10, timeout_unit="sec")
async def test_hexagon_grid(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clk_period = 10
        cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test Cases
    # Note: The input format uses raw strings from the prompt examples
    test_inputs = [
        "3\n-1 2 -1\n2 2\n1 -1 1\n",
        "7\n-1 4 5 1 0 -1 -1\n-1 3 2 0 0 1\n-1 4 -1 1 0 -1 -1\n1 3 4 2 2 4\n0 2 3 -1 4 4 2\n-1 4 4 3 3 2\n1 -1 -1 -1 4 2 -1\n",
        "3\n-1 2 -1\n2 2\n-1 -1 -1\n"
    ]
    expected_outputs = [1, 1, 4]
    
    passed = 0
    failed = 0
    
    for idx, (inp_str, exp_val) in enumerate(zip(test_inputs, expected_outputs)):
        cocotb.log.info(f"Running Test Case {idx+1}")
        
        # Parse Input
        valid_list, constr_list = parse_grid(inp_str)
        
        # Drive Inputs
        # Assuming dut has flat arrays grid_valid[0:68] and grid_constraint[0:68]
        # If grid_constraint is a vector array, we need to handle bit slicing
        
        for i in range(69):
            # Drive grid_valid
            if has_signal(dut, f'grid_valid_{i}'):
                getattr(dut, f'grid_valid_{i}').value = valid_list[i]
            elif hasattr(dut, 'grid_valid') and hasattr(dut.grid_valid, '__iter__'):
                 dut.grid_valid[i].value = valid_list[i]
            else:
                 # Fallback or packed vector logic would go here
                 # Assuming flat indexable for this benchmark
                 if hasattr(dut, 'grid_valid'):
                     dut.grid_valid[i].value = valid_list[i]

            # Drive grid_constraint (3 bits per cell)
            val = constr_list[i]
            bits = 3
            # Handle different access patterns for packed arrays
            if hasattr(dut, 'grid_constraint') and not hasattr(dut.grid_constraint, '__iter__'):
                 # It's likely a packed vector. 
                 # We accumulate into a large integer for the whole vector
                 # Or assume the testbench knows the structure. 
                 # Given the complexity, we'll assume unpacked or indexable for safety.
                 pass
            
            # Safe assignment for indexable signals
            if has_signal(dut, f'grid_constraint_{i}'):
                getattr(dut, f'grid_constraint_{i}').value = clamp_to_width(val, bits)
            elif hasattr(dut, 'grid_constraint') and hasattr(dut.grid_constraint, '__iter__'):
                dut.grid_constraint[i].value = clamp_to_width(val, bits)
        
        # If grid_constraint is a single packed vector (unlikely given the prompt spec style but possible):
        # We would calculate a single large integer here. 
        # However, the prompt spec suggests indexable inputs for clarity.
        
        # Start Sequence
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        timeout_cycles = 20000 # Large timeout for search operations
        done_seen = False
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            cocotb.log.error(f"Test {idx+1} Timeout after {timeout_cycles} cycles")
            failed += 1
            continue
            
        # Check Result
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
            if result == exp_val:
                cocotb.log.info(f"Test {idx+1} Passed: Result {result}")
                passed += 1
            else:
                cocotb.log.error(f"Test {idx+1} Failed: Expected {exp_val}, Got {result}")
                failed += 1
        else:
            cocotb.log.error(f"Test {idx+1} Result undefined")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")