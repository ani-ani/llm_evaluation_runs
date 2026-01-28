import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

# --- Test Logic ---
CLK_NS = 10
MAX_CYCLES = 250000

# Helper to encode statement types
def encode_stmt(stmt_line, N):
    parts = stmt_line.strip().split()
    speaker = int(parts[0])
    # First part is 'truther', 'fabulist', etc.
    op = parts[1]
    
    stmt_type = 0
    arg1 = 0
    arg2 = 0
    arg1_type = 0 # For base propositions
    
    if op == 'truther':
        stmt_type = 0
        arg1 = int(parts[2])
        arg1_type = 0
    elif op == 'fabulist':
        stmt_type = 1
        arg1 = int(parts[2])
        arg1_type = 1
    elif op == 'charlatan':
        stmt_type = 2
        arg1 = int(parts[2])
        arg1_type = 2
    elif op == 'not':
        stmt_type = 3
        # 'not <base> <n>' -> parts: 1=not, 2=base, 3=n
        sub_op = parts[2]
        if sub_op == 'truther': arg1_type = 0
        elif sub_op == 'fabulist': arg1_type = 1
        elif sub_op == 'charlatan': arg1_type = 2
        arg1 = int(parts[3])
    elif op == 'and':
        stmt_type = 4
        # 'and <base1> <n1> <base2> <n2>'
        # Parts: 2(base1), 3(n1), 4(base2), 5(n2)
        sub1 = parts[2]; n1 = int(parts[3])
        sub2 = parts[4]; n2 = int(parts[5])
        # Encode n1 in lower 3 bits, n2 in next 3 bits
        arg1 = n1
        arg2 = n2
    elif op == 'xor':
        stmt_type = 5
        # 'xor <base1> <n1> <base2> <n2>'
        sub1 = parts[2]; n1 = int(parts[3])
        sub2 = parts[4]; n2 = int(parts[5])
        arg1 = n1
        arg2 = n2
        
    return speaker, stmt_type, arg1, arg2, arg1_type

@cocotb.test(timeout_time=MAX_CYCLES * CLK_NS * 2, timeout_unit="ns")
async def test_candidate_character(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await Timer(CLK_NS * 2, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_data = [
        ("1 2\n1 charlatan 1\n1 not charlatan 1\n", ["charlatan"]),
        ("2 1\n1 and fabulist 1 fabulist 2\n", ["fabulist", "truther"]),
        ("3 2\n1 fabulist 3\n3 and truther 1 truther 2\n", ["truther", "fabulist", "fabulist"]) 
    ]
    
    for idx, (inp_str, expected_types) in enumerate(test_data):
        cocotb.log.info(f"Running Test Case {idx+1}")
        lines = inp_str.strip().split('\n')
        first_line = lines[0].split()
        N = int(first_line[0])
        K = int(first_line[1])
        
        # Load Phase
        if has_signal(dut, 'stmt_count'):
            dut.stmt_count.value = K
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream statements if interface supports it
        if has_signal(dut, 'load_en'):
            for i in range(K):
                stmt_line = lines[i+1]
                sp, st, a1, a2, a1t = encode_stmt(stmt_line, N)
                dut.speaker_id.value = sp
                dut.stmt_type.value = st
                dut.arg1.value = a1
                dut.arg2.value = a2
                dut.arg1_type.value = a1t
                dut.load_en.value = 1
                await RisingEdge(dut.clk)
            dut.load_en.value = 0
        else:
            # Assumption: Interface might have parallel inputs if not streaming
            # Or the DUT processes internal strings. For robustness, we assume streaming or parallel load.
            # If no load signal, we assume DUT is ready or we wait.
            await RisingEdge(dut.clk)
        
        # Wait for computation
        timeout_counter = 0
        found = False
        
        # Collect results
        results = []
        
        while timeout_counter < MAX_CYCLES:
            await RisingEdge(dut.clk)
            timeout_counter += 1
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found = True
                break
        
        if not found:
            raise TestFailure(f"Test {idx+1}: Timeout after {MAX_CYCLES} cycles")
            
        # Read results (DUT should output N results sequentially or in parallel)
        # Assuming sequential output on 'result' and 'result_type' with 'result_valid'
        # If DUT has parallel outputs like res_1_type, res_2_type...
        
        collected = {}
        if has_signal(dut, 'res_1_type'):
             # Parallel output assumption
             for i in range(1, N+1):
                 res_sig = getattr(dut, f'res_{i}_type')
                 if is_value_defined(res_sig.value):
                     t_val = int(res_sig.value)
                     if t_val == 0: collected[i] = "truther"
                     elif t_val == 1: collected[i] = "fabulist"
                     elif t_val == 2: collected[i] = "charlatan"
        else:
             # Sequential or single output
             # Let's assume the DUT has a mechanism to iterate or outputs an array.
             # If 'result' is valid for current candidate index
             if has_signal(dut, 'result_index') and has_signal(dut, 'result_type'):
                 for i in range(N):
                     # Manually check if index i is valid? Or DUT iterates automatically?
                     # Assuming we need to read while done is high or check validity
                     pass
             
             # Fallback: Check result_valid. If valid, read result_type.
             # If the DUT outputs a packed array of types, decode it.
             if has_signal(dut, 'result_packed'):
                 packed_val = int(dut.result_packed.value)
                 for i in range(1, N+1):
                     shift = (i-1) * 2
                     t_val = (packed_val >> shift) & 3
                     if t_val == 0: collected[i] = "truther"
                     elif t_val == 1: collected[i] = "fabulist"
                     elif t_val == 2: collected[i] = "charlatan"
             elif has_signal(dut, 'result_valid'):
                 if int(dut.result_valid.value) == 1:
                     t_val = int(dut.result_type.value)
                     c_id = int(dut.result.value)
                     if t_val == 0: collected[c_id] = "truther"
                     elif t_val == 1: collected[c_id] = "fabulist"
                     elif t_val == 2: collected[c_id] = "charlatan"
                     
        # Verify
        if len(collected) != N:
             raise TestFailure(f"Test {idx+1}: Expected {N} results, got {len(collected)}. Collected: {collected}")
             
        for i in range(1, N+1):
            if str(collected[i]) != expected_types[i-1]:
                raise TestFailure(f"Test {idx+1}: Candidate {i} expected {expected_types[i-1]}, got {collected[i]}")
        
        cocotb.log.info(f"Test {idx+1} Passed")
