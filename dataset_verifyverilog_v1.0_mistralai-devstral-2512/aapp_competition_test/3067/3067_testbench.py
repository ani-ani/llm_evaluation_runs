import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Scaled parameters: 8 sequences, 16 max length, 8-bit values
MAX_SEQUENCES = 8
MAX_LEN = 16
DATA_WIDTH = 8
LEN_WIDTH = 4
TOTAL_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 500

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, width):
    max_val = (1 << width) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Test data generation
def generate_test_case():
    n = random.randint(1, 8)
    sequences = []
    lens = []
    for _ in range(n):
        l = random.randint(1, MAX_LEN)
        seq = [random.randint(1, 127) for _ in range(l)]
        sequences.append(seq)
        lens.append(l)
    return sequences, lens

def compute_expected(sequences):
    # Python simulation of greedy algorithm
    pointers = [0] * len(sequences)
    solution = []
    total = sum(len(s) for s in sequences)
    
    for _ in range(total):
        # Find candidates (sequences with remaining cards)
        candidates = []
        for i, seq in enumerate(sequences):
            if pointers[i] < len(seq):
                candidates.append(i)
        
        if not candidates:
            break
        
        # Select best candidate
        best_seq = None
        best_val = None
        best_lookahead = []
        
        for idx in candidates:
            cur_val = sequences[idx][pointers[idx]]
            # Get lookahead values (next up to 4 elements)
            lookahead = []
            for offset in range(1, min(5, len(sequences[idx]) - pointers[idx])):
                lookahead.append(sequences[idx][pointers[idx] + offset])
            
            # Compare: first by current value, then by lookahead
            if best_seq is None:
                best_seq = idx
                best_val = cur_val
                best_lookahead = lookahead
            else:
                # Compare current values
                if cur_val < best_val:
                    best_seq = idx
                    best_val = cur_val
                    best_lookahead = lookahead
                elif cur_val == best_val:
                    # Tie-break by lookahead
                    tie_broken = False
                    for j in range(min(len(lookahead), len(best_lookahead))):
                        if lookahead[j] < best_lookahead[j]:
                            best_seq = idx
                            best_lookahead = lookahead
                            tie_broken = True
                            break
                        elif lookahead[j] > best_lookahead[j]:
                            tie_broken = True
                            break
                    if not tie_broken and len(lookahead) < len(best_lookahead):
                        # If one sequence is shorter after tie, prefer shorter? Actually prefer lexicographically smaller
                        # Shorter sequence is "smaller" if we consider end as infinity, so prefer longer lookahead?
                        # Let's just keep current best
                        pass
        
        # Select best
        solution.append(sequences[best_seq][pointers[best_seq]])
        pointers[best_seq] += 1
    
    return solution

def flatten_input(sequences, lens):
    # seq_data: packed array of MAX_SEQUENCES * MAX_LEN * DATA_WIDTH bits
    # We'll assign individually
    return sequences, lens

# Build test cases
def build_test_cases():
    cases = []
    # Case 1: Simple disjoint
    seq1 = [[2], [100], [1]]
    lens1 = [1, 1, 1]
    cases.append((seq1, lens1, [1, 2, 100]))
    
    # Case 2: Tie with lookahead
    seq2 = [[10, 20, 30, 40, 50], [28, 27]]
    lens2 = [5, 2]
    cases.append((seq2, lens2, [10, 20, 28, 27, 30, 40, 50]))
    
    # Case 3: Tie at start
    seq3 = [[5, 1, 2], [5, 1, 1]]
    lens3 = [3, 3]
    cases.append((seq3, lens3, [5, 1, 1, 5, 1, 2]))
    
    return cases

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_solution_sequence(dut):
    # Check for required signals
    if not has_signal(dut, 'clk') or not has_signal(dut, 'rst_n'):
        raise TestFailure("Missing clk or rst_n signals")
    if not has_signal(dut, 'start') or not has_signal(dut, 'done'):
        raise TestFailure("Missing start or done signals")
    if not has_signal(dut, 'out_val') or not has_signal(dut, 'out_valid'):
        raise TestFailure("Missing out_val or out_valid signals")
    
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = build_test_cases()
    random.seed(42)
    for _ in range(3):
        seq, lens, expected = generate_test_case()
        test_cases.append((seq, lens, compute_expected(seq)))
    
    passed = 0
    failed = 0
    
    for i, (sequences, lens, expected_output) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}")
        cocotb.log.info(f"  Input sequences: {sequences}")
        cocotb.log.info(f"  Expected: {expected_output}")
        
        try:
            # Prepare input data
            total_len = sum(len(s) for s in sequences)
            
            # Check if dut has seq_data as array
            # We'll try to assign using getattr or direct array
            # For simplicity, assume individual signals seq_data_0_0, seq_data_0_1, etc.
            # But more likely it's seq_data[0:7][0:15] or seq_data[0:127]
            # We'll check for common patterns
            
            # Pattern 1: seq_data as single array
            if has_signal(dut, 'seq_data'):
                # Pack or assign sequentially
                # Assuming seq_data is a vector of total_len * DATA_WIDTH
                # But constraint says up to 8*16=128 elements
                flat_data = []
                for s_idx, s in enumerate(sequences):
                    flat_data.extend(s)
                    # Pad remaining
                    remaining = MAX_LEN - len(s)
                    flat_data.extend([0] * remaining)
                # If it's a single packed array, we need to pack it
                # But in Verilog, arrays can be assigned element-wise in simulation
                # However, cocotb has restrictions
                # Let's assume dut.seq_data is an array of 128 8-bit signals
                # We'll try to assign individually
                total_elements = MAX_SEQUENCES * MAX_LEN
                for idx in range(total_elements):
                    if idx < total_len:
                        s_idx = 0
                        elem_idx = idx
                        # Map flat index to sequence
                        mapped = False
                        for si, s in enumerate(sequences):
                            if elem_idx < len(s):
                                val = sequences[si][elem_idx]
                                mapped = True
                                break
                            else:
                                elem_idx -= len(s)
                        if not mapped:
                            val = 0
                        dut.seq_data[idx].value = clamp_to_width(val, DATA_WIDTH)
                    else:
                        dut.seq_data[idx].value = 0
            # Pattern 2: seq_data as 2D array (seq_data_i_j)
            else:
                for s_idx, s in enumerate(sequences):
                    for j in range(MAX_LEN):
                        if j < len(s):
                            val = s[j]
                            signal_name = f'seq_data_{s_idx}_{j}'
                        else:
                            val = 0
                            signal_name = f'seq_data_{s_idx}_{j}'
                        if has_signal(dut, signal_name):
                            getattr(dut, signal_name).value = clamp_to_width(val, DATA_WIDTH)
            
            # Assign lens
            if has_signal(dut, 'seq_lens'):
                for i_len, l in enumerate(lens):
                    dut.seq_lens[i_len].value = clamp_to_width(l, LEN_WIDTH)
                # Pad remaining lens to 0
                for i_len in range(len(lens), MAX_SEQUENCES):
                    dut.seq_lens[i_len].value = 0
            else:
                for i_len in range(MAX_SEQUENCES):
                    if i_len < len(lens):
                        val = lens[i_len]
                    else:
                        val = 0
                    signal_name = f'seq_lens_{i_len}'
                    if has_signal(dut, signal_name):
                        getattr(dut, signal_name).value = clamp_to_width(val, LEN_WIDTH)
            
            # Assign total_len
            if has_signal(dut, 'total_len'):
                dut.total_len.value = clamp_to_width(total_len, TOTAL_WIDTH)
            
            # Assert start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Collect output
            output = []
            cycles = 0
            while cycles < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycles += 1
                if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                    if is_value_defined(dut.out_val.value):
                        out_val = int(dut.out_val.value)
                        output.append(out_val)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            # Wait a bit more to ensure done is seen
            await Timer(10, units='ns')
            
            # Check results
            if output != expected_output:
                raise TestFailure(f"Output mismatch: expected {expected_output}, got {output}")
            
            # Check if done was asserted
            if not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                raise TestFailure("Done signal not asserted")
            
            passed += 1
            cocotb.log.info(f"  PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
