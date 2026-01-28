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

# Fixed-point helpers
Q16_FRAC = 16
def float_to_fixed(f):
    return int(f * (1 << Q16_FRAC))

def fixed_to_float(v):
    return v / (1 << Q16_FRAC)

# Adjacency matrix packing for 8 nodes
def pack_row(row, n=8):
    packed = 0
    for i in range(n):
        packed |= (row[i] & 1) << i
    return packed

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_mtr_meeting(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    # Clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational test
        await Timer(100, units='ns')

    # Test cases: (adj_matrix, n, start_s, start_t, expected_time, desc)
    test_cases = [
        # Sample 1: 3 nodes line 0-1-2, start (0,2) -> meet in 1 min
        (
            [[0,1,0], [1,0,1], [0,1,0]],  # adjacency
            3,                               # n
            0,                               # start_s
            2,                               # start_t
            1.0,                             # expected
            "3-node line (0-1-2), start (0,2)"
        ),
        # Sample 2: 4 nodes, disconnected components
        (
            [[0,1,0,0], [1,0,0,0], [0,0,0,1], [0,0,1,0]],
            4,
            0,
            3,
            None,  # should be never_meet
            "Disconnected graph"
        ),
        # Additional test: single node (trivial meet)
        (
            [[0]],
            1,
            0,
            0,
            0.0,
            "Single node"
        ),
        # Additional test: 2 nodes connected
        (
            [[0,1], [1,0]],
            2,
            0,
            1,
            1.0,
            "2-node connected"
        ),
    ]

    passed = 0
    failed = 0
    
    for i, (adj, n, start_s, start_t, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write adjacency matrix
            for r in range(8):
                for c in range(8):
                    sig_name = f'adj_{r}_{c}'
                    if has_signal(dut, sig_name):
                        val = adj[r][c] if (r < n and c < n) else 0
                        getattr(dut, sig_name).value = val
            
            # Write inputs
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'start_s'):
                dut.start_s.value = start_s
            if has_signal(dut, 'start_t'):
                dut.start_t.value = start_t
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            cycles = 0
            done = False
            while cycles < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycles += 1
                if has_signal(dut, 'done'):
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
            
            if not done:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            
            # Check results
            if has_signal(dut, 'never_meet'):
                never = int(dut.never_meet.value) if is_value_defined(dut.never_meet.value) else 0
                if never:
                    if expected is not None:
                        raise TestFailure(f"Expected meet in {expected}, got never_meet flag")
                    else:
                        cocotb.log.info(f"  PASS: Correctly never meet")
                        passed += 1
                        continue
                else:
                    if expected is None:
                        raise TestFailure(f"Expected never_meet, but never_meet=0")
            
            # Get expected time
            if has_signal(dut, 'expected_time'):
                if not is_value_defined(dut.expected_time.value):
                    raise TestFailure("Result undefined")
                result_val = int(dut.expected_time.value)
                result_float = fixed_to_float(result_val)
                
                if expected is None:
                    raise TestFailure(f"Expected never_meet, got {result_float}")
                
                # Allow tolerance
                diff = abs(result_float - expected)
                if diff > 1e-6:
                    raise TestFailure(f"Expected {expected}, got {result_float}, diff={diff}")
                
                cocotb.log.info(f"  PASS: Result = {result_float} (0x{result_val:08X})")
                passed += 1
            else:
                raise TestFailure("Missing expected_time signal")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")