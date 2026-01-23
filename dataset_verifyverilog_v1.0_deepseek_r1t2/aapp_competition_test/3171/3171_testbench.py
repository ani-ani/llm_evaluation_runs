import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# ============================================================================
# HELPER FUNCTIONS
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
# PARSING FUNCTIONS
# ============================================================================

def parse_token(tokens, pos):
    """Parse a proposition starting at tokens[pos]. Returns (parsed_op, new_pos)."""
    token = tokens[pos]
    
    # Leaf operators
    if token in ['truther', 'fabulist', 'charlatan']:
        op_code = {'truther': 0, 'fabulist': 1, 'charlatan': 2}[token]
        arg1 = int(tokens[pos + 1])
        return (op_code, arg1, 0), pos + 2
    
    # Unary operator
    elif token == 'not':
        # Parse operand
        (op_code, arg1, arg2), new_pos = parse_token(tokens, pos + 1)
        return (3, arg1, arg2), new_pos  # 3 = not
    
    # Binary operators
    elif token in ['and', 'xor']:
        op_code = 4 if token == 'and' else 5
        # Parse first operand
        (op1, a1, a2), pos1 = parse_token(tokens, pos + 1)
        # Parse second operand
        (op2, b1, b2), pos2 = parse_token(tokens, pos1)
        # For simplicity, we'll store indices to sub-statements
        return (op_code, a1, b1), pos2
    
    else:
        raise ValueError(f"Unexpected token: {token}")

def preprocess_input(input_str):
    """Convert raw input to structured format for HDL."""
    lines = input_str.strip().split('\n')
    first_line = lines[0].split()
    N = int(first_line[0])
    K = int(first_line[1])
    
    utterances = []
    for i in range(1, K + 1):
        line = lines[i]
        parts = line.split()
        speaker = int(parts[0])
        statement_tokens = parts[1:]
        
        # Parse statement
        (op_code, arg1, arg2), _ = parse_token(statement_tokens, 0)
        
        utterances.append({
            'speaker': speaker,
            'op': op_code,
            'arg1': arg1,
            'arg2': arg2
        })
    
    return N, K, utterances

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_utterance_arrays(dut, utterances, N, K):
    """Write utterance data to DUT arrays."""
    # Initialize arrays with zeros
    for i in range(K):
        if has_signal(dut, f'u_speaker_{i}'):
            getattr(dut, f'u_speaker_{i}').value = 0
            getattr(dut, f'u_op_{i}').value = 0
            getattr(dut, f'u_arg1_{i}').value = 0
            getattr(dut, f'u_arg2_{i}').value = 0
        else:
            dut.u_speaker[i].value = 0
            dut.u_op[i].value = 0
            dut.u_arg1[i].value = 0
            dut.u_arg2[i].value = 0
    
    # Write actual utterances
    for i, utt in enumerate(utterances):
        if i >= K:
            break
        
        speaker = clamp_to_width(utt['speaker'], 4)
        op = clamp_to_width(utt['op'], 4)
        arg1 = clamp_to_width(utt['arg1'], 4)
        arg2 = clamp_to_width(utt['arg2'], 4)
        
        if has_signal(dut, f'u_speaker_{i}'):
            getattr(dut, f'u_speaker_{i}').value = speaker
            getattr(dut, f'u_op_{i}').value = op
            getattr(dut, f'u_arg1_{i}').value = arg1
            getattr(dut, f'u_arg2_{i}').value = arg2
        else:
            dut.u_speaker[i].value = speaker
            dut.u_op[i].value = op
            dut.u_arg1[i].value = arg1
            dut.u_arg2[i].value = arg2

async def read_results(dut, N):
    """Read result types for all candidates."""
    results = []
    for i in range(N):
        if has_signal(dut, f'result_type_{i}'):
            val = getattr(dut, f'result_type_{i}').value
        else:
            val = dut.result_type[i].value
        
        if is_value_defined(val):
            results.append(int(val))
        else:
            results.append(None)
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_debate_solver(dut):
    """Test the debate solver with provided examples."""
    
    # Configuration
    N_MAX = 4
    K_MAX = 8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_inputs = [
        "1 2\n1 charlatan 1\n1 not charlatan 1\n",
        "2 1\n1 and fabulist 1 fabulist 2\n",
        "3 2\n1 fabulist 3\n3 and truther 1 truther 2\n"
    ]
    
    test_outputs = [
        [2],  # charlatan (encoded as 2)
        [1, 0],  # fabulist, truther
        [0, 1, 1]  # truther, fabulist, fabulist
    ]
    
    for test_idx, (input_str, expected) in enumerate(zip(test_inputs, test_outputs)):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Running Test Case {test_idx + 1}")
        dut._log.info(f"{'='*60}")
        
        # Parse input
        N, K, utterances = preprocess_input(input_str)
        dut._log.info(f"Parsed: N={N}, K={K}")
        
        # Validate sizes
        if N > N_MAX or K > K_MAX:
            dut._log.warning(f"Test case exceeds maximum sizes (N={N}, K={K})")
            continue
        
        # Write utterance data
        await write_utterance_arrays(dut, utterances, N, K_MAX)
        
        # Write count parameters
        if has_signal(dut, 'num_utterances'):
            dut.num_utterances.value = K
        if has_signal(dut, 'num_candidates'):
            dut.num_candidates.value = N
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read results
        results = await read_results(dut, N)
        
        # Convert to readable format
        type_map = {0: 'truther', 1: 'fabulist', 2: 'charlatan'}
        result_str = [type_map.get(r, 'unknown') for r in results]
        
        dut._log.info(f"Results: {result_str}")
        dut._log.info(f"Expected: {[type_map.get(r, 'unknown') for r in expected]}")
        
        # Verify
        for i in range(N):
            if results[i] != expected[i]:
                raise TestFailure(
                    f"Test {test_idx + 1}, candidate {i+1}: "
                    f"expected {expected[i]} ({type_map[expected[i]]}), "
                    f"got {results[i]} ({type_map.get(results[i], 'unknown')})"
                )
        
        dut._log.info(f"Test {test_idx + 1} PASSED")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("\n" + "="*60)
    dut._log.info("ALL TESTS PASSED")
    dut._log.info("="*60)
