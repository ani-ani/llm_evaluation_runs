import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 80
N_WIDTH = 2
LEN_WIDTH = 2
OUTPUT_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 50

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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def encode_tuple(name_str, score1, score2):
    # Encode 8-byte string + 2 scores into 80 bits
    # Bytes 0-7: ASCII string (8 chars)
    # Bits 64-71: score1
    # Bits 72-79: score2
    packed = 0
    # String bytes (right-aligned in 80-bit field)
    for i in range(min(8, len(name_str))):
        packed |= (ord(name_str[i]) & 0xFF) << (i * 8)
    # If name shorter than 8 bytes, pad with spaces (0x20)
    for i in range(len(name_str), 8):
        packed |= 0x20 << (i * 8)
    # Scores at bits 64-79
    packed |= (score1 & 0xFF) << 64
    packed |= (score2 & 0xFF) << 72
    return packed

def decode_expected(name_str, n):
    if n == 0:
        # Return first character (as integer)
        return ord(name_str[0]) if name_str else ord(' ')
    elif n == 1:
        return 0  # Placeholder, actual value in test cases
    else:  # n == 2
        return 0  # Placeholder

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_extract_nth_element(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test data from Python problem
    tuples_data = [
        ('Greyson Fulton', 98, 99),
        ('Brady Kent', 97, 96),
        ('Wyatt Knott', 91, 94),
        ('Beau Turnbull', 94, 98)
    ]
    
    test_cases = [
        # (n, expected_results)
        (0, ['G', 'B', 'W', 'B']),  # First character of each name
        (2, [99, 96, 94, 98]),      # Third element (score2)
        (1, [98, 97, 91, 94]),      # Second element (score1)
    ]

    passed = 0
    failed = 0

    for test_idx, (n, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: Extract element n={n}")
        
        try:
            # Reset before each test
            await reset_dut(dut)
            
            # Prepare input data stream
            input_stream = []
            for name, s1, s2 in tuples_data:
                input_stream.append(encode_tuple(name, s1, s2))
            
            total_tuples = len(tuples_data)
            
            if is_seq:
                # Sequential test
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Feed tuples and capture outputs
                received = []
                tuple_idx = 0
                
                # Create clock cycles for processing
                # In sequential, we need to drive data_in for each tuple
                for cycle in range(total_tuples + 5):  # Extra cycles for done
                    await RisingEdge(dut.clk)
                    
                    # Drive input for current tuple if needed
                    if tuple_idx < total_tuples:
                        dut.data_in.value = input_stream[tuple_idx]
                        dut.n.value = n
                        dut.len.value = total_tuples
                        tuple_idx += 1
                    
                    # Read output
                    if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
                        out_val = int(dut.data_out.value)
                        received.append(out_val)
                        cocotb.log.info(f"Cycle {cycle}: Output {out_val}")
                
                # Wait for done
                done_captured = False
                for _ in range(10):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_captured = True
                        break
                
                if not done_captured:
                    raise TestFailure("Done signal not received")
                
                # Validate
                if len(received) != len(expected):
                    raise TestFailure(f"Expected {len(expected)} outputs, got {len(received)}")
                
                for i, (exp, got) in enumerate(zip(expected, received)):
                    if isinstance(exp, str):
                        exp_val = ord(exp)
                    else:
                        exp_val = exp
                    if got != exp_val:
                        raise TestFailure(f"Index {i}: Expected {exp_val}, got {got}")
                
                cocotb.log.info(f"Test {test_idx + 1} PASSED")
                passed += 1
                
            else:
                # Combinational test - simulate multiple cycles
                await Timer(50, units='ns')
                cocotb.log.info("Combinational test simulation")
                # For combinational, we test first tuple only
                dut.data_in.value = input_stream[0]
                dut.n.value = n
                dut.len.value = total_tuples
                await Timer(10, units='ns')
                
                if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
                    out_val = int(dut.data_out.value)
                    exp_val = expected[0]
                    if isinstance(exp_val, str):
                        exp_val = ord(exp_val)
                    if out_val == exp_val:
                        cocotb.log.info(f"Test {test_idx + 1} PASSED")
                        passed += 1
                    else:
                        raise TestFailure(f"Expected {exp_val}, got {out_val}")
                else:
                    raise TestFailure("valid_out not asserted")

        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx + 1} FAILED: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")