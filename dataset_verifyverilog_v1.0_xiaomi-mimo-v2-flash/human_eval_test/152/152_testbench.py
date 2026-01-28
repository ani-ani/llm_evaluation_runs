import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_compare_module(dut):
    DATA_WIDTH = 8
    ARRAY_SIZE = 8
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(3):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational, set all inputs
        dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0
    
    # Helper to write array values
    def write_arrays(scores, guesses, length):
        # Clamp and set all array elements
        for i in range(ARRAY_SIZE):
            score_val = from_signed(scores[i], DATA_WIDTH) if i < len(scores) else 0
            guess_val = from_signed(guesses[i], DATA_WIDTH) if i < len(guesses) else 0
            
            score_port = getattr(dut, f'score_{i}', None)
            guess_port = getattr(dut, f'guess_{i}', None)
            
            if score_port:
                score_port.value = clamp_to_width(score_val, DATA_WIDTH)
            if guess_port:
                guess_port.value = clamp_to_width(guess_val, DATA_WIDTH)
        
        # Set length if signal exists
        if has_signal(dut, 'length'):
            dut.length.value = length
    
    # Helper to read results
    def read_results():
        diffs = []
        for i in range(ARRAY_SIZE):
            diff_port = getattr(dut, f'diff_{i}', None)
            if diff_port:
                diffs.append(int(diff_port.value))
        return diffs
    
    # Test cases from problem
    test_cases = [
        ([1,2,3,4,5,1], [1,2,3,4,2,-2], 6, [0,0,0,0,3,3]),
        ([0,0,0,0,0,0], [0,0,0,0,0,0], 6, [0,0,0,0,0,0]),
        ([1,2,3], [-1,-2,-3], 3, [2,4,6]),
        ([1,2,3,5], [-1,2,3,4], 4, [2,0,0,1]),
        ([0,5,0,0,0,4], [4,1,1,0,0,-2], 6, [4,4,1,0,0,6])
    ]
    
    passed = 0
    failed = 0
    
    for idx, (scores, guesses, length, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: scores={scores}, guesses={guesses}")
        try:
            # Write inputs
            write_arrays(scores, guesses, length)
            
            if is_seq:
                # Trigger computation
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done with timeout
                done_found = False
                for cycle in range(MAX_CYCLES + 10):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                        if int(dut.done.value) == 1:
                            done_found = True
                            break
                
                if not done_found:
                    raise TestFailure(f"Done signal not asserted within {MAX_CYCLES} cycles")
            else:
                # Combinational: wait a bit for propagation
                await Timer(10, units='ns')
            
            # Read results
            results = read_results()
            
            # Compare with expected
            # Pad expected with zeros to match array size
            expected_padded = expected + [0] * (len(results) - len(expected))
            
            if results != expected_padded[:len(results)]:
                raise TestFailure(f"Expected {expected_padded[:len(results)]}, got {results}")
            
            passed += 1
            cocotb.log.info(f"Test {idx+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")