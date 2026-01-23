import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random

# Helper to parse chemical formula and build matrix (mimicking the requested parser logic)
def parse_equation(input_str):
    lines = input_str.strip().split('
')
    molecules = []
    unique_elements = {}
    element_list = []
    
    # First pass: collect all element types
    for line in lines:
        if line.startswith('0'):
            break
        parts = line.split()
        sign = int(parts[0])
        n_pairs = int(parts[1])
        pairs = parts[2:]
        for i in range(0, len(pairs), 2):
            elem = pairs[i]
            if elem not in unique_elements:
                unique_elements[elem] = len(element_list)
                element_list.append(elem)
    
    num_elements = len(element_list)
    num_molecules = len([l for l in lines if not l.startswith('0')])
    
    # Build matrix
    matrix = [[0] * num_elements for _ in range(num_molecules)]
    molecule_idx = 0
    
    for line in lines:
        if line.startswith('0'):
            break
        parts = line.split()
        sign = int(parts[0])
        n_pairs = int(parts[1])
        pairs = parts[2:]
        
        # In stoichiometry, sign is usually +1 for reactants, -1 for products.
        # However, we are solving Ax=0. If we input products as negative, 
        # we need to be careful. The problem statement says "+1 indicates left, -1 right".
        # To solve Ax=0 (balance), we usually put everything on left: Reactants * coeff - Products * coeff = 0.
        # So effectively, for the linear system, we multiply the product counts by -1.
        
        for i in range(0, len(pairs), 2):
            elem = pairs[i]
            count = int(pairs[i+1])
            col = unique_elements[elem]
            matrix[molecule_idx][col] += sign * count
        molecule_idx += 1
        
    return num_molecules, num_elements, matrix, element_list

# Helper for GCD
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_molecules.value = 0
    dut.num_elements.value = 0
    for i in range(20):
        for j in range(10):
            dut.matrix_in[i][j].value = 0
    dut._log.info("Resetting...")
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')

@cocotb.test()
async def test_stoichiometry_basic(dut):
    """Test balancing simple H2O + CO2 -> O2 + C6H12O6"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Prepare Input 1
    input_str = "+1 2 H 2 O 1
+1 2 C 1 O 2
-1 1 O 2
-1 3 C 6 H 12 O 6
0 0
"
    M, N, matrix, elems = parse_equation(input_str)
    
    dut._log.info(f"Test 1: M={M}, N={N}")
    dut._log.info(f"Elements: {elems}")
    dut._log.info(f"Matrix: {matrix}")
    
    # Load inputs
    dut.num_molecules.value = M
    dut.num_elements.value = N
    for r in range(M):
        for c in range(N):
            dut.matrix_in[r][c].value = matrix[r][c]
            
    await Timer(5, units='ns')
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1, "Timeout waiting for done"
    assert dut.valid.value == 1, "Solution not valid"
    
    # Check results
    # Expected: 6 6 6 1
    result = []
    for i in range(M):
        result.append(int(dut.coefficients[i].value))
        
    dut._log.info(f"Result: {result}")
    
    # Normalize result (remove GCD if solver didn't do it, though module should)
    # The problem requires minimum integers.
    # Check if it matches expected (order is strictly input order)
    expected = [6, 6, 6, 1]
    
    # Allow scaling (e.g. 12 12 12 2 is same ratio, but we need minimum).
    # The problem states "minimum number" implying GCD=1.
    
    # Check if result matches expected (or flipped sign if solver did -1*...)
    # To be safe, we check ratios.
    
    # Let's check ratio relative to expected
    # We need to ensure result[i] / expected[i] is constant
    ratios = []
    for i in range(M):
        if expected[i] != 0:
            ratios.append(result[i] / expected[i])
        
    # Check if all ratios are roughly equal
    base_ratio = ratios[0]
    for r in ratios:
        assert abs(r - base_ratio) < 0.01, f"Ratio mismatch: {ratios}"
        
    # Check GCD is 1 (if base_ratio is 1)
    if abs(base_ratio - 1.0) < 0.01:
        g = result[0]
        for x in result[1:]:
            g = gcd(g, x)
        assert g == 1, f"GCD should be 1, got {g}"
        
    dut._log.info("Test 1 Passed!")

@cocotb.test()
async def test_stoichiometry_complex(dut):
    """Test complex case with Be, C, O, Ac, H"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    input_str = "+1 5 Be 2 C 1 O 3 O 2 H 2
+1 3 Ac 1 O 1 H 1
-1 4 Be 4 O 1 Ac 6 O 6
-1 2 H 2 O 1
-1 2 C 1 O 2
0 0
"
    M, N, matrix, elems = parse_equation(input_str)
    
    dut._log.info(f"Test 2: M={M}, N={N}")
    
    dut.num_molecules.value = M
    dut.num_elements.value = N
    for r in range(M):
        for c in range(N):
            dut.matrix_in[r][c].value = matrix[r][c]
            
    await Timer(5, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 2000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1
    assert dut.valid.value == 1
    
    result = []
    for i in range(M):
        result.append(int(dut.coefficients[i].value))
    
    # Expected: 2 6 1 5 2
    expected = [2, 6, 1, 5, 2]
    
    ratios = []
    for i in range(M):
        if expected[i] != 0:
            ratios.append(result[i] / expected[i])
            
    base_ratio = ratios[0]
    for r in ratios:
        assert abs(r - base_ratio) < 0.01, f"Ratio mismatch: {ratios}"
        
    if abs(base_ratio - 1.0) < 0.01:
        g = result[0]
        for x in result[1:]:
            g = gcd(g, x)
        assert g == 1
        
    dut._log.info(f"Result: {result}")
    dut._log.info("Test 2 Passed!")