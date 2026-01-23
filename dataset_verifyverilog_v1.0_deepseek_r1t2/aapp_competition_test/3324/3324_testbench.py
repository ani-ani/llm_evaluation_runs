import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
COEFF_WIDTH = 10
MAX_ELEMENTS = 10
MAX_MOLECULES = 20
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CHEMICAL EQUATION PARSER
# ============================================================================

def parse_equation(input_str):
    """
    Parse input format and build matrix A[e,m] = sign_m * count_m,e
    Returns: (matrix, num_elements, num_molecules, element_map, molecule_signs)
    """
    lines = input_str.strip().split('\n')
    molecules = []
    
    # Parse molecules
    for line in lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        if parts[0] == '0' and parts[1] == '0':
            break
        
        sign = int(parts[0])
        N = int(parts[1])
        pairs = parts[2:]
        
        mol = {'sign': sign, 'elements': {}}
        i = 0
        while i < len(pairs):
            elem = pairs[i]
            count = int(pairs[i+1])
            mol['elements'][elem] = mol['elements'].get(elem, 0) + count
            i += 2
        molecules.append(mol)
    
    # Map elements to indices
    all_elements = set()
    for mol in molecules:
        all_elements.update(mol['elements'].keys())
    element_map = {elem: idx for idx, elem in enumerate(sorted(all_elements))}
    
    # Build matrix
    num_elements = len(element_map)
    num_molecules = len(molecules)
    matrix = [[0 for _ in range(num_molecules)] for _ in range(num_elements)]
    
    for m_idx, mol in enumerate(molecules):
        for elem, count in mol['elements'].items():
            e_idx = element_map[elem]
            matrix[e_idx][m_idx] = mol['sign'] * count
    
    return matrix, num_elements, num_molecules, element_map, [m['sign'] for m in molecules]

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_matrix_entry(dut, value, elem_idx, mol_idx):
    """Write a single matrix entry to the DUT."""
    dut.entry_value.value = clamp_to_width(value, DATA_WIDTH)
    dut.entry_elem.value = elem_idx
    dut.entry_mol.value = mol_idx
    dut.entry_valid.value = 1
    await RisingEdge(dut.clk)
    dut.entry_valid.value = 0

async def write_matrix(dut, matrix, num_elements, num_molecules):
    """Write entire matrix to DUT."""
    for e_idx in range(num_elements):
        for m_idx in range(num_molecules):
            value = matrix[e_idx][m_idx]
            await write_matrix_entry(dut, value, e_idx, m_idx)

async def read_coeffs(dut, num_molecules):
    """Read coefficients from DUT."""
    coeffs = []
    for i in range(num_molecules):
        if has_signal(dut, f'coeffs_{i}'):
            val = getattr(dut, f'coeffs_{i}').value
        else:
            # Indexed array
            if hasattr(dut.coeffs, '__getitem__'):
                val = dut.coeffs[i].value
            else:
                raise TestFailure(f"Cannot access coeffs[{i}]")
        
        if is_value_defined(val):
            coeffs.append(int(val))
        else:
            coeffs.append(None)
    return coeffs

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.entry_valid.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_stoichiometry_balancer(dut):
    """Test the stoichiometry balancer module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (
            "+1 2 H 2 O 1\n+1 2 C 1 O 2\n-1 1 O 2\n-1 3 C 6 H 12 O 6\n0 0\n",
            [6, 6, 6, 1],
            "Simple case: H2O + CO2 -> O2 + C6H12O6"
        ),
        (
            "+1 5 Be 2 C 1 O 3 O 2 H 2\n+1 3 Ac 1 O 1 H 1\n-1 4 Be 4 O 1 Ac 6 O 6\n-1 2 H 2 O 1\n-1 2 C 1 O 2\n0 0\n",
            [2, 6, 1, 5, 2],
            "Complex case with multiple elements"
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_str, expected_coeffs, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        cocotb.log.info(f"{'='*60}")
        
        try:
            # Parse input
            matrix, num_elems, num_mols, elem_map, signs = parse_equation(input_str)
            cocotb.log.info(f"Parsed: {num_elems} elements, {num_mols} molecules")
            cocotb.log.info(f"Element map: {elem_map}")
            cocotb.log.info(f"Signs: {signs}")
            cocotb.log.info(f"Matrix shape: {num_elems} x {num_mols}")
            
            # Verify expected coefficients count matches
            if len(expected_coeffs) != num_mols:
                raise TestFailure(f"Expected {len(expected_coeffs)} coeffs but have {num_mols} molecules")
            
            # Reset again for clean test
            if is_sequential:
                await reset_dut(dut)
            
            # Write configuration
            if has_signal(dut, 'num_elements'):
                dut.num_elements.value = num_elems
            if has_signal(dut, 'num_molecules'):
                dut.num_molecules.value = num_mols
            
            # Write matrix
            cocotb.log.info("Writing matrix...")
            await write_matrix(dut, matrix, num_elems, num_mols)
            
            # Wait a bit for matrix to settle
            await Timer(100, units='ns')
            
            # Start computation
            if is_sequential:
                cocotb.log.info("Starting computation...")
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                await Timer(10, units='ns')  # Propagation delay
            else:
                # Combinational - wait longer
                await Timer(1000, units='ns')
            
            # Read coefficients
            coeffs = read_coeffs(dut, num_mols)
            cocotb.log.info(f"Read coefficients: {coeffs}")
            
            # Validate
            if None in coeffs:
                raise TestFailure(f"Some coefficients are undefined: {coeffs}")
            
            # Check against expected
            # Note: Expected may be in different order, need to match by molecule
            # For simplicity, we check exact match
            if coeffs != expected_coeffs:
                raise TestFailure(f"Mismatch! Expected {expected_coeffs}, got {coeffs}")
            
            # Verify minimal (no common factor > 1)
            def gcd(a, b):
                while b:
                    a, b = b, a % b
                return a
            
            g = coeffs[0]
            for c in coeffs[1:]:
                g = gcd(g, c)
            
            if g > 1:
                raise TestFailure(f"Coefficients have common factor {g}: {coeffs}")
            
            # Verify all positive and within range
            for c in coeffs:
                if c <= 0 or c > 1000:
                    raise TestFailure(f"Coefficient {c} out of range (1-1000)")
            
            cocotb.log.info(f"  PASS: {coeffs} (minimized, positive, within range)")
            passed += 1
            
        except Exception as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            if test_idx == 0:
                raise  # Re-raise first failure for debugging
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")