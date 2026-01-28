import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'b_valid'): dut.b_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_drinking_musicians(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    test_cases = [
        {
            'T': 8, 
            'N': 3, 
            'breaks': [4, 4, 4], 
            'expected_starts': [0, 2, 4],
            'desc': 'Sample 1: 8 3, 4 4 4'
        },
        {
            'T': 10, 
            'N': 5, 
            'breaks': [7, 5, 1, 2, 3], 
            'expected_starts': [3, 3, 9, 0, 0],
            'desc': 'Sample 2: 10 5, 7 5 1 2 3'
        },
        {
            'T': 20,
            'N': 4,
            'breaks': [5, 5, 5, 5],
            'expected_starts': [0, 0, 10, 10], # Or similar valid schedule
            'desc': 'Small uniform case'
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['desc']}")
        
        # Start sequence
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Provide T and N
        # Assuming interface accepts T, N before or after start. 
        # Based on spec: inputs are latched or valid during process.
        # Let's assume T and N are provided on inputs before/during start.
        # But standard handshake is: Start -> Input Stream -> Output Stream.
        # Let's adjust to a stream interface where we feed data.
        
        # In the spec provided in prompt, inputs t_in, n_in, b_in, b_valid are defined.
        # We will feed T and N once, then stream B's.
        
        # Wait for internal reset if any
        await RisingEdge(dut.clk)
        
        # Feed T and N. If they are simple inputs, we just set them.
        # If they need a handshake, we assume b_valid covers it or separate valid.
        # Let's assume t_in, n_in are latched when start is high or b_valid is high.
        # To be safe, we'll just set the values and strobe b_valid for the sequence.
        
        # Set T and N. If the design expects them on the same bus as B or separate.
        # Spec says: t_in, n_in, b_in. 
        # Let's assume we set t_in and n_in, then pulse b_valid=0 (or separate signal) to latch them?
        # Or simpler: t_in and n_in are just inputs. We set them, then stream breaks.
        
        dut.t_in.value = tc['T']
        dut.n_in.value = tc['N']
        
        received_starts = []
        
        # Stream breaks
        for i, b_val in enumerate(tc['breaks']):
            dut.b_in.value = b_val
            dut.b_valid.value = 1
            await RisingEdge(dut.clk)
            dut.b_valid.value = 0
            
            # Wait for s_valid
            found_valid = False
            for _ in range(50000): # Wait reasonable cycles per musician
                await RisingEdge(dut.clk)
                if is_value_defined(dut.s_valid.value) and int(dut.s_valid.value) == 1:
                    s = int(dut.s_out.value)
                    received_starts.append(s)
                    found_valid = True
                    break
            
            if not found_valid:
                raise TestFailure(f"Timeout waiting for start time for musician {i}")
            
            # Optional: verify partial schedule correctness
            # (Check that overlaps <= 2 for received intervals so far)
            # This requires reconstructing the schedule list.
        
        # Wait for done
        await wait_for_done(dut)
        
        # Verify results
        # Note: Expected outputs in prompt examples might not be the ONLY solution.
        # We should verify the constraints rather than exact values, 
        # unless the algorithm is deterministic.
        # The prompt says "determine how to schedule", implying a valid schedule.
        
        cocotb.log.info(f"Received starts: {received_starts}")
        
        # Constraint Verification
        # 1. All breaks inside [0, T]
        for i in range(tc['N']):
            s = received_starts[i]
            b = tc['breaks'][i]
            if s < 0 or s + b > tc['T']:
                raise TestFailure(f"Musician {i}: Interval [{s}, {s+b}) out of bounds [0, {tc['T']}]")
        
        # 2. Max 2 overlaps
        # Create events
        events = []
        for i in range(tc['N']):
            s = received_starts[i]
            e = s + tc['breaks'][i]
            events.append((s, 1))   # Start
            events.append((e, -1))  # End
        
        events.sort()
        current_overlap = 0
        max_overlap = 0
        # Check discrete points (assuming integer minutes)
        # Note: if one ends at t and another starts at t, they don't overlap.
        # We sort by time, and if times are equal, process ends before starts.
        # The sort above: (t, type). -1 < 1, so ends come before starts at same time.
        
        for t, delta in events:
            current_overlap += delta
            if current_overlap > max_overlap:
                max_overlap = current_overlap
        
        if max_overlap > 2:
            raise TestFailure(f"Max overlap {max_overlap} exceeds 2")
            
        # If exact match with sample outputs is required (strict testing):
        if 'expected_starts' in tc:
            if received_starts != tc['expected_starts']:
                # Check if it's just a permutation or different valid schedule
                # For this problem, usually specific output is expected (greedy/sorted).
                # We'll log a warning but pass if constraints are met, 
                # or fail if strict match is required.
                # Given the prompt says "determine how to schedule", any valid is usually accepted.
                # But sample outputs are specific.
                # Let's verify constraints strictly first.
                cocotb.log.info(f"Received starts differ from sample, but constraints are met. Accepting.")
                # If strict match needed for benchmark, uncomment below:
                # if received_starts != tc['expected_starts']:
                #     raise TestFailure(f"Starts mismatch. Got {received_starts}, Expected {tc['expected_starts']}")

    # End of tests
    cocotb.log.info("All tests passed!")
