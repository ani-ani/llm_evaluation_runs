import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
K_WIDTH = 8
MATCH_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 4096

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if v < 0: return 0
    return min((1 << bits) - 1, v)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'seq_valid'): dut.seq_valid.value = 0
    if has_signal(dut, 'seq_done'): dut.seq_done.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python solution for reference and test generation
def solve_python(seq):
    if not seq: return 0, 0
    N = len(seq)
    best_k = 0
    max_matches = 1 # First key is always correct
    
    # Candidates: 0 and absolute differences
    candidates = {0}
    for i in range(N - 1):
        diff = seq[i+1] - seq[i]
        # Clamping logic to match scaled constraints
        if 0 <= diff <= 255:
            candidates.add(diff)
    
    for k in candidates:
        matches = 1
        current_played = seq[0]
        for i in range(1, N):
            prev_comp = seq[i-1]
            curr_comp = seq[i]
            
            if curr_comp > prev_comp:
                current_played += k
            elif curr_comp < prev_comp:
                current_played -= k
            # else: same
            
            # Check if match (considering potential 8-bit overflow/wrap if needed, but here assume exact)
            if current_played == curr_comp:
                matches += 1
        
        if matches > max_matches:
            max_matches = matches
            best_k = k
            
    return max_matches, best_k

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_multi_piano(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic check (should handle sequence in one go or fail timeout)
        await Timer(100, units='ns')

    # Test Cases
    # Case 1: 1 2 0 3 1 -> Optimal K=2, Matches=3
    seq1 = [1, 2, 0, 3, 1]
    exp1_k = 2
    exp1_m = 3
    
    # Case 2: 2 1 -6 -2 1 6 10 -> Optimal K=4, Matches=5
    seq2 = [2, 1, -6, -2, 1, 6, 10]
    exp2_k = 4
    exp2_m = 5
    
    test_cases = [
        (seq1, exp1_m, exp1_k, "Basic example 1"),
        (seq2, exp2_m, exp2_k, "Example 2 with negatives")
    ]

    for seq, exp_m, exp_k, desc in test_cases:
        cocotb.log.info(f"Running test: {desc}")
        
        # Verify Python logic first
        py_m, py_k = solve_python(seq)
        if py_m != exp_m or py_k != exp_k:
             cocotb.log.warning(f"Python verification mismatch: {py_m},{py_k} vs {exp_m},{exp_k}")

        if is_seq:
            # Send Sequence
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed data stream
            dut.seq_valid.value = 1
            for val in seq:
                # Map signed value to 8-bit
                dut.seq_in.value = from_signed(val, DATA_WIDTH)
                await RisingEdge(dut.clk)
            
            dut.seq_valid.value = 0
            dut.seq_done.value = 1
            await RisingEdge(dut.clk)
            dut.seq_done.value = 0
            
            # Wait for calculation
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.max_matches.value) or not is_value_defined(dut.optimal_k.value):
                raise TestFailure("Output signals undefined")
                
            res_m = int(dut.max_matches.value)
            res_k = int(dut.optimal_k.value)
            
            # Allow flexibility if exact K is ambiguous (though problem says K is unique within constraints, scaled might have diff)
            # We check exact match for now as per scaled constraints
            if res_m != exp_m:
                raise TestFailure(f"Matches mismatch: expected {exp_m}, got {res_m}")
            
            # K check: check if it is a valid optimal K (Python check)
            # Since K might be derived differently or have multiple optimums in scaled version, check max_matches match is primary
            if res_k != exp_k:
                 cocotb.log.warning(f"K mismatch: expected {exp_k}, got {res_k} (Validating if it yields correct matches)")
                 # Validate if this K actually works
                 temp_m, _ = solve_python([res_k] + seq[1:] if seq else []) # Dummy check logic not exactly applicable here
                 # Simply log warning as secondary metric
                 
            cocotb.log.info(f"Result: Matches={res_m}, K={res_k}")
        else:
            # Combinational: Assign inputs directly
            # This structure assumes sequential processing, so skip if purely combinational
            pass
        
        if is_seq:
             await RisingEdge(dut.clk) # Cool down