import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random
from collections import Counter

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_DISTINCT = 8
MAX_P = 4
MAX_Q = 4
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width, max_size):
    """Write values to array, handling different interface styles."""
    # Try 2D array first (like matrix)
    try:
        arr = getattr(dut, array_name)
        # For 2D array, assume it's indexed as arr[i][j]
        # In this testbench we only write to 1D arrays
        pass
    except (AttributeError, TypeError):
        pass
    
    # For 1D arrays (number_values, count_values)
    # Try individual ports (name_0, name_1, ...)
    for i in range(max_size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0
        else:
            # Try indexed array
            try:
                if i < len(values):
                    getattr(dut, array_name)[i].value = clamp_to_width(values[i], element_width)
                else:
                    getattr(dut, array_name)[i].value = 0
            except (AttributeError, TypeError):
                # Neither found, skip
                pass

async def read_array(dut, array_name, size, rows=1, cols=1):
    """Read array values, handling 2D arrays."""
    results = []
    if rows == 1 and cols == 1:
        # 1D array
        for i in range(size):
            # Try indexed array
            try:
                val = getattr(dut, array_name)[i].value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
                # Try individual ports
                port_name = f"{array_name}_{i}"
                if has_signal(dut, port_name):
                    val = getattr(dut, port_name).value
                    if is_value_defined(val):
                        results.append(int(val))
                    else:
                        results.append(None)
                else:
                    results.append(None)
    else:
        # 2D array
        for i in range(rows):
            row = []
            for j in range(cols):
                try:
                    val = getattr(dut, array_name)[i][j].value
                    if is_value_defined(val):
                        row.append(int(val))
                    else:
                        row.append(None)
                except (AttributeError, TypeError):
                    row.append(None)
            results.append(row)
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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
# REFERENCE IMPLEMENTATION (Python)
# ============================================================================

def reference_beautiful_rectangle(numbers, counts, valid_distinct):
    """Compute maximum beautiful rectangle and fill it."""
    # Sort by count descending (already sorted in testbench)
    nums = [numbers[i] for i in range(valid_distinct)]
    cnts = [counts[i] for i in range(valid_distinct)]
    
    # Compute maximum rectangle
    best_area = 0
    best_p = 0
    best_q = 0
    n = sum(cnts)
    
    for p in range(4, 0, -1):  # from max to 1
        total_usable = 0
        for c in cnts:
            total_usable += min(c, p)
        q = total_usable // p
        if q >= p and p * q > best_area:
            best_area = p * q
            best_p = p
            best_q = q
    
    # Generate sequence of numbers
    seq = []
    cnts_used = cnts.copy()
    while len(seq) < best_area:
        for i in range(valid_distinct):
            if cnts_used[i] > 0:
                copies = min(cnts_used[i], best_p)
                for _ in range(copies):
                    if len(seq) >= best_area:
                        break
                    seq.append(nums[i])
                    cnts_used[i] -= 1
                if len(seq) >= best_area:
                    break
    
    # Fill matrix in diagonal order
    matrix = [[0 for _ in range(best_q)] for _ in range(best_p)]
    idx = 0
    for col in range(best_q):
        for row in range(best_p):
            if idx < len(seq):
                matrix[row][(col + row) % best_q] = seq[idx]
                idx += 1
    
    return best_p, best_q, best_area, matrix

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_beautiful_rectangle(dut):
    """Main test function for beautiful_rectangle module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: generate random inputs
    for test_idx in range(20):  # Number of random tests
        # Generate random distinct numbers (1 to 8 distinct)
        num_distinct = random.randint(1, MAX_DISTINCT)
        numbers = random.sample(range(1, 100), num_distinct)
        counts = [random.randint(1, 16) for _ in range(num_distinct)]
        
        # Sort by count descending (important for algorithm)
        sorted_pairs = sorted(zip(numbers, counts), key=lambda x: x[1], reverse=True)
        numbers = [pair[0] for pair in sorted_pairs]
        counts = [pair[1] for pair in sorted_pairs]
        
        # Compute reference
        ref_p, ref_q, ref_area, ref_matrix = reference_beautiful_rectangle(numbers, counts, num_distinct)
        
        cocotb.log.info(f"\nTest {test_idx+1}: {num_distinct} distinct numbers")
        cocotb.log.info(f"Reference: p={ref_p}, q={ref_q}, area={ref_area}")
        
        # Write inputs to DUT
        # Set valid_distinct
        dut.valid_distinct.value = num_distinct
        # Write arrays
        for i in range(MAX_DISTINCT):
            if i < num_distinct:
                dut.number_values[i].value = numbers[i]
                dut.count_values[i].value = counts[i]
            else:
                dut.number_values[i].value = 0
                dut.count_values[i].value = 0
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        area = int(dut.area.value)
        p = int(dut.p.value)
        q = int(dut.q.value)
        
        cocotb.log.info(f"DUT output: p={p}, q={q}, area={area}")
        
        # Validate dimensions
        if p != ref_p or q != ref_q or area != ref_area:
            # The DUT might find a different rectangle with same area, which is acceptable
            if area != ref_area:
                raise TestFailure(f"Area mismatch: expected {ref_area}, got {area}")
            if p * q != area:
                raise TestFailure(f"p*q != area: p={p}, q={q}, area={area}")
        
        # Read matrix
        matrix = []
        for i in range(p):
            row = []
            for j in range(q):
                val = dut.matrix[i][j].value
                if is_value_defined(val):
                    row.append(int(val))
                else:
                    raise TestFailure(f"Matrix element [{i}][{j}] undefined")
            matrix.append(row)
        
        # Validate matrix properties
        # 1. All numbers must be from input
        # 2. Each row must have distinct values
        # 3. Each column must have distinct values
        # 4. Total count of each number must not exceed input count
        
        # Flatten matrix and count
        flat = [val for row in matrix for val in row]
        # Check distinct rows
        for row in matrix:
            if len(set(row)) != len(row):
                raise TestFailure(f"Row {row} has duplicates")
        # Check distinct columns
        for j in range(q):
            col = [matrix[i][j] for i in range(p)]
            if len(set(col)) != len(col):
                raise TestFailure(f"Column {col} has duplicates")
        # Check each number's count
        from collections import Counter
        used_counts = Counter(flat)
        for num, used in used_counts.items():
            if num not in numbers:
                raise TestFailure(f"Number {num} in matrix not in input")
            total_avail = sum(cnt for n, cnt in zip(numbers, counts) if n == num)
            if used > total_avail:
                raise TestFailure(f"Number {num} used {used} times, but only {total_avail} available")
        
        # Check that matrix uses exactly p*q cells
        if len(flat) != p * q:
            raise TestFailure(f"Matrix has {len(flat)} cells, expected {p*q}")
        
        cocotb.log.info(f"Matrix validation passed")
        
        # Log matrix
        for row in matrix:
            cocotb.log.info(f"  {row}")
        
        # Wait a few cycles before next test
        await Timer(100, units='ns')
    
    cocotb.log.info("All tests passed!")
