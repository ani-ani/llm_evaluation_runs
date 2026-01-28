import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_string(s, max_len=16):
    """Convert string to list of ASCII bytes, padded with zeros"""
    result = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        result[i] = ord(c)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_list_to_nested_dict(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (id_list, name_list, score_list, expected_results)
    test_cases = [
        (
            ["S001", "S002", "S003", "S004"],
            ["Adina Park", "Leyton Marsh", "Duncan Boyle", "Saim Richards"],
            [85, 98, 89, 92],
            [
                {"id_len": 4, "id_data": "S001", "name_len": 10, "name_data": "Adina Park", "score": 85},
                {"id_len": 4, "id_data": "S002", "name_len": 11, "name_data": "Leyton Marsh", "score": 98},
                {"id_len": 4, "id_data": "S003", "name_len": 12, "name_data": "Duncan Boyle", "score": 89},
                {"id_len": 4, "id_data": "S004", "name_len": 11, "name_data": "Saim Richards", "score": 92}
            ],
            "Test 1: Original test case"
        ),
        (
            ["abc", "def", "ghi", "jkl"],
            ["python", "program", "language", "programs"],
            [100, 200, 300, 400],
            [
                {"id_len": 3, "id_data": "abc", "name_len": 6, "name_data": "python", "score": 100},
                {"id_len": 3, "id_data": "def", "name_len": 7, "name_data": "program", "score": 200},
                {"id_len": 3, "id_data": "ghi", "name_len": 8, "name_data": "language", "score": 300},
                {"id_len": 3, "id_data": "jkl", "name_len": 8, "name_data": "programs", "score": 400}
            ],
            "Test 2: Test case 2"
        ),
        (
            ["A1", "A2", "A3", "A4"],
            ["java", "C", "C++", "DBMS"],
            [10, 20, 30, 40],
            [
                {"id_len": 2, "id_data": "A1", "name_len": 4, "name_data": "java", "score": 10},
                {"id_len": 2, "id_data": "A2", "name_len": 1, "name_data": "C", "score": 20},
                {"id_len": 2, "id_data": "A3", "name_len": 3, "name_data": "C++", "score": 30},
                {"id_len": 2, "id_data": "A4", "name_len": 4, "name_data": "DBMS", "score": 40}
            ],
            "Test 3: Test case 3"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (id_list, name_list, score_list, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"Input IDs: {id_list}")
        cocotb.log.info(f"Input Names: {name_list}")
        cocotb.log.info(f"Input Scores: {score_list}")
        
        try:
            # Set entry_valid to all 1s (all entries valid)
            dut.entry_valid.value = 0b1111
            
            # Write ID strings (4 chars each, max 4 entries)
            for entry in range(4):
                id_str = id_list[entry]
                id_chars = pack_string(id_str, max_len=4)
                for char_idx in range(4):
                    sig_name = f'id_chars_{entry}_{char_idx}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = clamp_to_width(id_chars[char_idx], 8)
            
            # Write Name strings (16 chars each, max 4 entries)
            for entry in range(4):
                name_str = name_list[entry]
                name_chars = pack_string(name_str, max_len=16)
                for char_idx in range(16):
                    sig_name = f'name_chars_{entry}_{char_idx}'
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = clamp_to_width(name_chars[char_idx], 8)
            
            # Write scores
            for entry in range(4):
                sig_name = f'scores_{entry}'
                if has_signal(dut, sig_name):
                    getattr(dut, sig_name).value = clamp_to_width(score_list[entry], 8)
            
            # Trigger computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read and verify outputs
            result_valid = int(dut.result_valid.value) if has_signal(dut, 'result_valid') else 0b1111
            
            for entry in range(4):
                if not (result_valid & (1 << entry)):
                    cocotb.log.warning(f"Entry {entry} marked invalid, skipping")
                    continue
                
                exp = expected[entry]
                
                # Check ID length
                id_len_sig = f'output_id_len_{entry}'
                if has_signal(dut, id_len_sig):
                    got_id_len = int(getattr(dut, id_len_sig).value)
                    if got_id_len != exp["id_len"]:
                        raise TestFailure(
                            f"Entry {entry} ID length mismatch: expected {exp['id_len']}, got {got_id_len}"
                        )
                
                # Check ID data
                id_data_match = True
                for char_idx in range(4):
                    sig_name = f'output_id_data_{entry}_{char_idx}'
                    if has_signal(dut, sig_name):
                        got_char = int(getattr(dut, sig_name).value)
                        exp_char = ord(exp["id_data"][char_idx]) if char_idx < len(exp["id_data"]) else 0
                        if got_char != exp_char:
                            id_data_match = False
                            cocotb.log.error(
                                f"Entry {entry} ID char {char_idx}: expected '{exp_char}' ({exp_char}), got '{got_char}' ({got_char})"
                            )
                
                if not id_data_match:
                    raise TestFailure(f"Entry {entry} ID data mismatch")
                
                # Check Name length
                name_len_sig = f'output_name_len_{entry}'
                if has_signal(dut, name_len_sig):
                    got_name_len = int(getattr(dut, name_len_sig).value)
                    if got_name_len != exp["name_len"]:
                        raise TestFailure(
                            f"Entry {entry} name length mismatch: expected {exp['name_len']}, got {got_name_len}"
                        )
                
                # Check Name data
                name_data_match = True
                for char_idx in range(16):
                    sig_name = f'output_name_data_{entry}_{char_idx}'
                    if has_signal(dut, sig_name):
                        got_char = int(getattr(dut, sig_name).value)
                        exp_char = ord(exp["name_data"][char_idx]) if char_idx < len(exp["name_data"]) else 0
                        if got_char != exp_char:
                            name_data_match = False
                            cocotb.log.error(
                                f"Entry {entry} name char {char_idx}: expected '{exp_char}' ({exp_char}), got '{got_char}' ({got_char})"
                            )
                
                if not name_data_match:
                    raise TestFailure(f"Entry {entry} name data mismatch")
                
                # Check Score
                score_sig = f'output_score_{entry}'
                if has_signal(dut, score_sig):
                    got_score = int(getattr(dut, score_sig).value)
                    if got_score != exp["score"]:
                        raise TestFailure(
                            f"Entry {entry} score mismatch: expected {exp['score']}, got {got_score}"
                        )
                
                cocotb.log.info(f"Entry {entry}: PASS - ID: {exp['id_data']}, Name: {exp['name_data']}, Score: {exp['score']}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1}: PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1}: FAIL - {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Summary: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
