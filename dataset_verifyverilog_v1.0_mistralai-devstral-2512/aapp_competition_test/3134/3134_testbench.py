import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_parity_str(s):
    """Convert string '0110' to 16-bit integer (LSB = first char)"""
    val = 0
    for i, c in enumerate(s):
        if c == '1':
            val |= (1 << i)
    return val

def unpack_matrix_16x16(matrix_val):
    """Unpack 256-bit value to 16x16 2D list (row-major, row 0 at top)"""
    matrix = []
    for row in range(16):
        row_val = (matrix_val >> ((15 - row) * 16)) & 0xFFFF
        row_bits = [(row_val >> (15 - col)) & 1 for col in range(16)]
        matrix.append(row_bits)
    return matrix

def verify_reconstruction(row_str, col_str, matrix_2d):
    """Verify matrix satisfies parity constraints"""
    n = len(row_str)
    m = len(col_str)
    
    # Check row parities
    for i in range(n):
        row_sum = sum(matrix_2d[i][j] for j in range(m))
        if row_sum % 2 != int(row_str[i]):
            return False, f"Row {i+1} parity mismatch"
    
    # Check column parities
    for j in range(m):
        col_sum = sum(matrix_2d[i][j] for i in range(n))
        if col_sum % 2 != int(col_str[j]):
            return False, f"Column {j+1} parity mismatch"
    
    return True, "OK"

def calculate_expected_output(row_str, col_str):
    """Calculate expected matrix using greedy algorithm (from Python solution)"""
    n = len(row_str)
    m = len(col_str)
    
    # Initialize all zeros
    matrix = [[0] * m for _ in range(n)]
    
    # Step 1: For each row with odd parity, set last element to 1
    for i in range(n):
        if int(row_str[i]) == 1:
            matrix[i][m-1] = 1
    
    # Step 2: For each column, fix parity by setting last row element
    for j in range(m):
        col_sum = sum(matrix[i][j] for i in range(n))
        if col_sum % 2 != int(col_str[j]):
            matrix[n-1][j] = 1
    
    # Verify
    valid, _ = verify_reconstruction(row_str, col_str, matrix)
    return matrix if valid else None

def matrix_to_16x16_packed(matrix):
    """Convert n x m matrix to 16x16 packed 256-bit value"""
    packed = 0
    n = len(matrix)
    m = len(matrix[0])
    
    for i in range(16):
        for j in range(16):
            bit_val = 0
            if i < n and j < m:
                bit_val = matrix[i][j]
            
            # Pack: row 0 at bit 15, row 15 at bit 0
            packed |= (bit_val << ((15 - i) * 16 + (15 - j)))
    
    return packed

def pack_16x16_packed_from_str(row_str, col_str):
    """Convert string format to expected packed 16x16 matrix"""
    expected_matrix = calculate_expected_output(row_str, col_str)
    if expected_matrix is None:
        return None, False
    packed = matrix_to_16x16_packed(expected_matrix)
    return packed, True

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_matrix_reconstruction(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("0110", "1001", "Case 1: 4x4 example"),
        ("0", "1", "Case 2: 1x1 impossible"),
        ("11", "0110", "Case 3: 2x4 example")
    ]
    
    passed = 0
    failed = 0
    
    for i, (row_str, col_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Row parities: {row_str}")
        cocotb.log.info(f"  Col parities: {col_str}")
        
        try:
            n = len(row_str)
            m = len(col_str)
            
            if not is_seq:
                # Combinational module - just assign inputs
                dut.row_parity.value = pack_parity_str(row_str)
                dut.col_parity.value = pack_parity_str(col_str)
                dut.n.value = n
                dut.m.value = m
                await Timer(100, units='ns')
            else:
                # Sequential module
                dut.row_parity.value = pack_parity_str(row_str)
                dut.col_parity.value = pack_parity_str(col_str)
                dut.n.value = n
                dut.m.value = m
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                await wait_for_done(dut)
            
            # Check results
            if not is_value_defined(dut.done.value):
                raise TestFailure("done signal undefined")
            
            if int(dut.done.value) != 1:
                raise TestFailure(f"done signal not asserted (value: {dut.done.value})")
            
            # Calculate expected
            expected_packed, expected_possible = pack_16x16_packed_from_str(row_str, col_str)
            
            # Check impossible flag
            if not is_value_defined(dut.impossible.value):
                raise TestFailure("impossible signal undefined")
            
            impossible_actual = int(dut.impossible.value)
            
            if not expected_possible:
                # Should be impossible
                if impossible_actual != 1:
                    raise TestFailure(f"Expected impossible=1, got {impossible_actual}")
                if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 0:
                    raise TestFailure("When impossible, valid must be 0")
                cocotb.log.info("  Result: Impossible (as expected)")
                passed += 1
            else:
                # Should be possible
                if impossible_actual != 0:
                    raise TestFailure(f"Expected impossible=0, got {impossible_actual}")
                
                if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                    raise TestFailure("When possible, valid must be 1")
                
                if not is_value_defined(dut.matrix_out.value):
                    raise TestFailure("matrix_out undefined")
                
                actual_packed = int(dut.matrix_out.value)
                
                # Verify actual matrix satisfies constraints
                actual_matrix = unpack_matrix_16x16(actual_packed)
                valid, msg = verify_reconstruction(row_str, col_str, actual_matrix)
                
                if not valid:
                    raise TestFailure(f"Reconstructed matrix invalid: {msg}")
                
                # Check that it matches expected output
                if actual_packed != expected_packed:
                    # Unpack for debugging
                    exp_matrix = unpack_matrix_16x16(expected_packed)
                    act_matrix = unpack_matrix_16x16(actual_packed)
                    
                    # Log the matrices
                    cocotb.log.info("  Expected matrix (first rows):")
                    for r in range(min(n, 16)):
                        row_vals = ''.join(str(bit) for bit in exp_matrix[r][:m])
                        cocotb.log.info(f"    {row_vals}")
                    
                    cocotb.log.info("  Actual matrix (first rows):")
                    for r in range(min(n, 16)):
                        row_vals = ''.join(str(bit) for bit in act_matrix[r][:m])
                        cocotb.log.info(f"    {row_vals}")
                    
                    # Even if binary value differs, check if it's still a valid solution
                    # The problem states: "smallest binary value" - but any valid solution
                    # is acceptable as long as it has maximum number of 1s
                    # Our expected calculation uses greedy approach which should be correct
                    raise TestFailure(f"Matrix output mismatch")
                
                cocotb.log.info("  Result: Valid reconstruction")
                passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")