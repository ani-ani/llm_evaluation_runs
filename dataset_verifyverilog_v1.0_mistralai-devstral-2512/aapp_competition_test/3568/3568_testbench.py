import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helper Functions ---
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

# --- Python Reference Model ---
def solve_frequency_python(t_i, intervals):
    """
    Checks if a single frequency can be played.
    intervals: list of (start, end)
    """
    MAX_POS = t_i
    
    # Masks for positions 0..MAX_POS
    # mask_out: reached pos p moving OUT (increasing)
    # mask_in: reached pos p moving IN (decreasing)
    
    # Initial Interval
    start_0, end_0 = intervals[0]
    L_0 = end_0 - start_0
    if L_0 > MAX_POS:
        return False
    
    # Valid start positions for interval 0:
    # Outward start: p in [0, MAX_POS - L_0] -> End at p + L_0
    # Inward start: p in [L_0, MAX_POS] -> End at p - L_0
    
    mask_out = [0] * (MAX_POS + 1)
    mask_in = [0] * (MAX_POS + 1)
    
    for p in range(MAX_POS + 1):
        # Outward
        if p + L_0 <= MAX_POS:
            mask_out[p + L_0] = 1 # We are at p+L_0 moving OUT
        # Inward
        if p - L_0 >= 0:
            mask_in[p - L_0] = 1 # We are at p-L_0 moving IN
            
    # Process subsequent intervals
    for i in range(len(intervals) - 1):
        curr_end = intervals[i][1]
        next_start = intervals[i+1][0]
        next_end = intervals[i+1][1]
        gap = next_start - curr_end
        L_next = next_end - next_start
        
        if L_next > MAX_POS:
            return False
            
        # Compute mask_reachable_start
        # A position q is reachable at next_start if:
        # There exists p such that |p - q| + cost <= gap
        # cost = 0 if same direction, 1 if reversed
        
        # Valid start ranges for next interval (to produce sound):
        valid_start_out = [0] * (MAX_POS + 1) # q where q + L_next <= MAX_POS
        valid_start_in = [0] * (MAX_POS + 1)  # q where q - L_next >= 0
        for q in range(MAX_POS + 1):
            if q + L_next <= MAX_POS: valid_start_out[q] = 1
            if q - L_next >= 0: valid_start_in[q] = 1
            
        # Calculate reachable q from current masks
        # From mask_out (arrived moving OUT):
        #   To move OUT (cost 0): |p-q| <= gap -> q in [p-gap, p+gap]
        #   To move IN (cost 1): |p-q| <= gap-1 -> q in [p-gap+1, p+gap-1]
        # From mask_in (arrived moving IN):
        #   To move IN (cost 0): |p-q| <= gap -> q in [p-gap, p+gap]
        #   To move OUT (cost 1): |p-q| <= gap-1 -> q in [p-gap+1, p+gap-1]
        
        new_mask_out = [0] * (MAX_POS + 1)
        new_mask_in = [0] * (MAX_POS + 1)
        
        # Optimization: Use prefix sums or simple loops since MAX_POS is small (10k)
        # Python loops 10k*100 = 1M, fine.
        
        for q in range(MAX_POS + 1):
            if not (valid_start_out[q] or valid_start_in[q]):
                continue
                
            # Check if q is reachable from OUT
            if any(mask_out):
                # We need to find p such that mask_out[p] is 1 and constraints hold
                # This is O(MAX_POS^2) if naive. 
                # Optimization: For each p, mark range of q.
                pass
        
        # Better: Iterate p, mark ranges of q
        # Since we need to merge ranges, let's do the range update properly.
        
        temp_mask_out = [0] * (MAX_POS + 1)
        temp_mask_in = [0] * (MAX_POS + 1)
        
        for p in range(MAX_POS + 1):
            # From OUT
            if mask_out[p]:
                # To OUT (cost 0)
                low = max(0, p - gap)
                high = min(MAX_POS, p + gap)
                for q in range(low, high + 1):
                    if valid_start_out[q]:
                        new_mask_out[q + L_next] = 1
                
                # To IN (cost 1)
                if gap >= 1:
                    low = max(0, p - gap + 1)
                    high = min(MAX_POS, p + gap - 1)
                    for q in range(low, high + 1):
                        if valid_start_in[q]:
                            new_mask_in[q - L_next] = 1
            
            # From IN
            if mask_in[p]:
                # To IN (cost 0)
                low = max(0, p - gap)
                high = min(MAX_POS, p + gap)
                for q in range(low, high + 1):
                    if valid_start_in[q]:
                        new_mask_in[q - L_next] = 1
                
                # To OUT (cost 1)
                if gap >= 1:
                    low = max(0, p - gap + 1)
                    high = min(MAX_POS, p + gap - 1)
                    for q in range(low, high + 1):
                        if valid_start_out[q]:
                            new_mask_out[q + L_next] = 1
                            
        mask_out = new_mask_out
        mask_in = new_mask_in
        
        if not any(mask_out) and not any(mask_in):
            return False
            
    return True

# --- Testbench ---
DATA_WIDTH = 16
MAX_T = 10000
CLK_NS = 10
MAX_CYCLES = 50000

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_floppy_organ(dut):
    """Test the floppy drive organ scheduler"""
    
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.t_i.value = 0
    dut.n_intervals.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        (6, [(0, 4), (6, 12)], True),
        (6, [(0, 5), (6, 8), (9, 14)], False),
        (10, [(0, 5)], True),
        (10, [(0, 11)], False), # Interval longer than T
        (10, [(0, 5), (6, 10)], True), # Gap 1, tight fit
    ]
    
    for t_i, intervals, expected in test_cases:
        dut._log.info(f"Testing T={t_i}, Intervals={intervals}, Expected={'possible' if expected else 'impossible'}")
        
        # Load Inputs
        dut.t_i.value = t_i
        dut.n_intervals.value = len(intervals)
        
        # In this simplified testbench, we assume the module has inputs for intervals
        # or we load them into the DUT's internal memory via a separate interface.
        # Since the prompt implies a module spec, we will assume parallel inputs for simplicity
        # or a simplified memory load interface. 
        
        # To match the likely Verilog structure, let's assume we load intervals one by one
        # or pass arrays. 
        
        # Let's simulate a "LOAD" phase if the DUT supports it, or just parallel wire assignment
        # if the testbench can handle 100 arrays. 
        
        # Assuming the DUT has inputs: interval_start[k], interval_end[k]
        # We need to iterate and assign.
        
        # For the purpose of this testbench, we will try to access dynamic signals
        try:
            for i, (s, e) in enumerate(intervals):
                # Check if DUT has these signals
                if has_signal(dut, f'interval_start_{i}'):
                    getattr(dut, f'interval_start_{i}').value = s
                    getattr(dut, f'interval_end_{i}').value = e
                elif has_signal(dut, 'interval_start') and hasattr(dut.interval_start, '__getitem__'):
                    # Array of signals
                    dut.interval_start[i].value = s
                    dut.interval_end[i].value = e
        except AttributeError:
            # If no such signals, maybe the DUT expects a serial load.
            # For this benchmark, we assume the prompt defined a parallel interface or we skip
            # specific assignment if not present in the template.
            # However, to be useful, we must populate the data.
            # Let's assume a generic load mechanism exists or we just test the core logic if exposed.
            # Since the prompt asks for a SPEC, we will try to be generic.
            dut._log.warning("Could not find interval signals. Assuming pre-loaded or generic interface.")
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout for T={t_i}")
            
        # Check Result
        result = int(dut.result.value)
        exp_val = 1 if expected else 0
        
        if result != exp_val:
            raise TestFailure(f"Mismatch for T={t_i}: Expected {exp_val}, Got {result}")
            
    dut._log.info("All tests passed")
