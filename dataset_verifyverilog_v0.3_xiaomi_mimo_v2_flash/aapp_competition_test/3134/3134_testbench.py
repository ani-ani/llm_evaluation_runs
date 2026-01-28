import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_matrix_recovery(dut):
    """Test matrix recovery module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, row_parity_str, col_parity_str, expected_result, description)
    test_cases = [
        # Sample Input 1: "0110" and "1001" -> 4x4 matrix
        (4, 4, "0110", "1001", "expected", "Sample 1: 4x4 matrix"),
        
        # Sample Input 2: "0" and "1" -> impossible
        (1, 1, "0", "1", "error", "Sample 2: impossible case"),
        
        # Sample Input 3: "11" and "0110" -> 2x4 matrix
        (2, 4, "11", "0110", "expected", "Sample 3: 2x4 matrix"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, row_parity_str, col_parity_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  n={n}, m={m}, row_parity={row_parity_str}, col_parity={col_parity_str}")
        
        try:
            # Convert string parities to integers
            row_parity_val = int(row_parity_str, 2) if row_parity_str else 0
            col_parity_val = int(col_parity_str, 2) if col_parity_str else 0
            
            # Write inputs
            dut.n.value = n
            dut.m.value = m
            dut.row_parity.value = row_parity_val
            dut.col_parity.value = col_parity_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check if error
            error = int(dut.error.value)
            
            if expected == "error":
                # Expected error
                if not error:
                    raise TestFailure(f"Expected error but got none")
                cocotb.log.info(f"  PASS: Correctly returned error")
                passed += 1
            else:
                # Expected success
                if error:
                    raise TestFailure(f"Expected success but got error")
                
                # Read matrix output (first n rows, first m columns)
                matrix_correct = True
                for row in range(n):
                    if not is_value_defined(dut.matrix_out[row].value):
                        raise TestFailure(f"Row {row} output is undefined")
                    
                    row_value = int(dut.matrix_out[row].value)
                    # Only check first m columns
                    for col in range(m):
                        bit = (row_value >> col) & 1
                        # We don't know the exact expected matrix due to multiple solutions
                        # Just check that parities are satisfied
                        pass
                
                # Verify parities are satisfied
                # Compute row parities
                for row in range(n):
                    row_bits = [(int(dut.matrix_out[row].value) >> col) & 1 for col in range(m)]
                    computed_parity = sum(row_bits) % 2
                    expected_parity = int(row_parity_str[row])
                    if computed_parity != expected_parity:
                        raise TestFailure(f"Row {row} parity mismatch: expected {expected_parity}, got {computed_parity}")
                
                # Compute column parities
                for col in range(m):
                    col_bits = []
                    for row in range(n):
                        row_val = int(dut.matrix_out[row].value)
                        col_bits.append((row_val >> col) & 1)
                    computed_parity = sum(col_bits) % 2
                    expected_parity = int(col_parity_str[col])
                    if computed_parity != expected_parity:
                        raise TestFailure(f"Column {col} parity mismatch: expected {expected_parity}, got {computed_parity}")
                
                cocotb.log.info(f"  PASS: Matrix satisfies all parity constraints")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")