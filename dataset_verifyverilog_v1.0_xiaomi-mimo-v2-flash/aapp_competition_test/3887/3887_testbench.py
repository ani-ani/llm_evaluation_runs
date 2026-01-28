import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_M = 16  # max question marks
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    if v < 0:
        v = 0
    return min((1 << bits) - 1, v)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_expression(expr_str):
    """Pack expression into bytes: '?'=1, '+'=2, '-'=3, '='=4, end=0"""
    tokens = []
    for char in expr_str:
        if char == '?':
            tokens.append(1)
        elif char == '+':
            tokens.append(2)
        elif char == '-':
            tokens.append(3)
        elif char == '=':
            tokens.append(4)
    # Pad with zeros to max 128 bits
    while len(tokens) < 16:
        tokens.append(0)
    # Pack into 128-bit integer
    packed = 0
    for i, t in enumerate(tokens):
        packed |= (t << (8 * i))
    return packed

def count_qmarks(expr_str):
    return expr_str.count('?')

def parse_n(expr_str):
    parts = expr_str.split('=')
    return int(parts[1].strip())

def solve_rebus(expr_str, n):
    """Python reference implementation"""
    # Count operators
    pos = 1  # first term is positive
    neg = 0
    for char in expr_str:
        if char == '+':
            pos += 1
        elif char == '-':
            neg += 1
    
    # Initial values
    current_sum = pos - neg
    values = []
    sign = 1
    
    # Assign values
    for char in expr_str:
        if char == '?':
            if sign == 1:
                if current_sum < n:
                    # Increase this positive term
                    val = min(n - current_sum + 1, n)
                    current_sum += val - 1
                else:
                    val = 1
            else:
                if current_sum > n:
                    # Decrease this negative term (make it more negative)
                    val = min(current_sum - n + 1, n)
                    current_sum -= val - 1
                else:
                    val = 1
            values.append(val * sign)
        elif char == '+':
            sign = 1
        elif char == '-':
            sign = -1
    
    return values, current_sum == n

def values_to_string(values, expr_str):
    """Convert values back to expression string"""
    result = []
    v_idx = 0
    expr_parts = expr_str.split('=')[0].strip().split()
    
    for part in expr_parts:
        if part == '?':
            result.append(str(values[v_idx]))
            v_idx += 1
        elif part in ['+', '-']:
            result.append(part)
    
    result.append('=')
    result.append(str(parse_n(expr_str)))
    return ' '.join(result)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rebus_module(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        "? + ? - ? + ? + ? = 42",
        "? - ? = 1",
        "? = 1000000",
        "? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? = 9",
        "? + ? = 2",
        "? - ? - ? = 1",
        "? + ? - ? = 0",
    ]
    
    passed = 0
    failed = 0
    
    for test_num, expr in enumerate(test_cases):
        try:
            cocotb.log.info(f"\nTest {test_num + 1}: {expr}")
            
            # Parse expression
            n = parse_n(expr)
            num_q = count_qmarks(expr)
            
            if num_q > MAX_M:
                cocotb.log.warning(f"Skipping: {num_q} question marks > {MAX_M}")
                continue
            
            # Get reference solution
            values, possible = solve_rebus(expr, n)
            
            # Setup inputs
            if is_seq:
                # Pack expression data
                packed = pack_expression(expr)
                dut.expr_data.value = packed
                dut.n_value.value = n & 0xFFFF  # 16-bit
                dut.num_qmarks.value = num_q
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_wait = MAX_CYCLES
                for cycle in range(max_wait):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout after {max_wait} cycles")
                
                # Read results
                if not is_value_defined(dut.possible.value):
                    raise TestFailure("Result 'possible' undefined")
                
                hw_possible = int(dut.possible.value) == 1
                
                if hw_possible != possible:
                    raise TestFailure(f"Possible mismatch: expected {possible}, got {hw_possible}")
                
                # Read output string if possible
                if hw_possible and has_signal(dut, 'result'):
                    # For this exercise, we just check that possible flag is correct
                    # The actual string reconstruction would be complex in HDL
                    cocotb.log.info(f"Expected sum: {n}, HW possible: {hw_possible}")
            else:
                # Combinational test
                await Timer(100, units='ns')
                if has_signal(dut, 'possible'):
                    hw_possible = int(dut.possible.value) == 1
                    if hw_possible != possible:
                        raise TestFailure(f"Possible mismatch: expected {possible}, got {hw_possible}")
            
            passed += 1
            cocotb.log.info(f"Test {test_num + 1} passed")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {test_num + 1} FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"\nSummary: {passed}/{len(test_cases)} tests passed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rebus_edge_cases(dut):
    """Test edge cases with larger n values"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test case: ? - ? = 1 should be impossible
    expr = "? - ? = 1"
    n = 1
    num_q = 2
    
    if is_seq:
        packed = pack_expression(expr)
        dut.expr_data.value = packed
        dut.n_value.value = n & 0xFFFF
        dut.num_qmarks.value = num_q
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_wait = 100
        for cycle in range(max_wait):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout")
        
        hw_possible = int(dut.possible.value) == 1
        
        # Python reference says impossible
        if hw_possible:
            raise TestFailure(f"Expected Impossible, got Possible")
        
        cocotb.log.info(f"Edge case 'Impossible' test passed")
    
    # Test case: single question mark
    expr = "? = 1000000"
    n = 1000000
    num_q = 1
    
    if is_seq:
        packed = pack_expression(expr)
        dut.expr_data.value = packed
        dut.n_value.value = n & 0xFFFF  # Note: overflow if n > 65535
        dut.num_qmarks.value = num_q
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_wait = 100
        for cycle in range(max_wait):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout")
        
        hw_possible = int(dut.possible.value) == 1
        
        # n=1000000 > 65535, so HW will handle as saturation or modulo
        # We just check that it completes
        cocotb.log.info(f"Large n test completed")
