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

# Global constants
MAX_N = 16
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 5000

def pack_seq(values, width=8, size=MAX_N):
    packed = 0
    for i in range(min(len(values), size)):
        packed |= (clamp_to_width(values[i], width) << (i * width))
    return packed

def unpack_seq(packed_val, width=8, size=MAX_N):
    vals = []
    for i in range(size):
        v = (packed_val >> (i * width)) & ((1 << width) - 1)
        vals.append(v)
    return vals

def unpack_array_like(dut, name, width=8, size=MAX_N):
    vals = []
    for i in range(size):
        if hasattr(getattr(dut, name), '__getitem__'):
            v = int(getattr(dut, name)[i].value)
        else:
            v = 0
        vals.append(v)
    return vals

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_frogs(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(2): await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        ([1, 5, 4, 3, 2, 6], [1, 2, 5, 4, 3, 6], 6),
        ([1, 5, 3, 2, 4], [1, 5, 4, 2, 3], 5)
    ]

    for idx, (start_list, target_list, n) in enumerate(test_cases):
        cocotb.log.info(f"\n--- Test Case {idx+1}: N={n} ---")
        
        # 1. Initialize inputs
        # Handle packed inputs if they exist, else individual array elements
        if has_signal(dut, 'start_seq'):
            dut.start_seq.value = pack_seq(start_list, DATA_WIDTH, MAX_N)
        elif has_signal(dut, 'start_seq_0'):
            for i in range(n):
                getattr(dut, f'start_seq_{i}').value = clamp_to_width(start_list[i], DATA_WIDTH)
        else:
            # Assuming array interface like dut.start_seq[i]
            for i in range(n):
                dut.start_seq[i].value = clamp_to_width(start_list[i], DATA_WIDTH)

        if has_signal(dut, 'target_seq'):
            dut.target_seq.value = pack_seq(target_list, DATA_WIDTH, MAX_N)
        elif has_signal(dut, 'target_seq_0'):
            for i in range(n):
                getattr(dut, f'target_seq_{i}').value = clamp_to_width(target_list[i], DATA_WIDTH)
        else:
            for i in range(n):
                dut.target_seq[i].value = clamp_to_width(target_list[i], DATA_WIDTH)

        if has_signal(dut, 'n'):
            dut.n.value = n

        # 2. Start signal
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            dut.start.value = 0
        
        # 3. Collect commands
        commands = []
        done_flag = False
        
        # Run simulation
        for cycle in range(MAX_CYCLES):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            
            # Check done
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    done_flag = True
                    cocotb.log.info(f"Done signal received at cycle {cycle}")
                    break
            
            # Check command valid
            cmd_valid = False
            if has_signal(dut, 'cmd_valid'):
                if is_value_defined(dut.cmd_valid.value) and int(dut.cmd_valid.value) == 1:
                    cmd_valid = True
            else:
                # If no valid signal, assume always valid when output is present (combinational check)
                if has_signal(dut, 'cmd_out') and is_value_defined(dut.cmd_out.value):
                    cmd_valid = True
            
            if cmd_valid:
                if has_signal(dut, 'cmd_out'):
                    cmd = int(dut.cmd_out.value)
                    if cmd > 0: # Filter out possible X or 0 if defined as null
                        # Avoid duplicates in same cycle if multiple triggers (unlikely in sequential FSM)
                        if not commands or commands[-1] != cmd:
                            commands.append(cmd)
                            cocotb.log.info(f"Cycle {cycle}: Command {cmd}")

        # 4. Verify result
        # To be fully correct, we should simulate the commands on the start sequence and check if it matches target
        # However, the problem just asks for *a* sequence. We check if done was asserted.
        if not done_flag:
             # Check if current state matches target manually via signals if exposed
             # If not exposed, we rely on done signal.
             raise TestFailure(f"Module did not assert done within {MAX_CYCLES} cycles")
        
        # Optional: Simulate commands to verify correctness
        if len(commands) > 0:
            current = list(start_list)
            for cmd in commands:
                try:
                    # Frog ID B makes B leaps. 
                    # In the sequence representation: find index of B.
                    # Swap with previous element B times.
                    idx = current.index(cmd)
                    for leap in range(cmd):
                        if idx > 0:
                            current[idx], current[idx-1] = current[idx-1], current[idx]
                            idx -= 1
                        else:
                            # Circle? Problem says "jumped over the frog in front of it, swapping places". 
                            # The example implies linear bubble sort behavior within the array.
                            # If at index 0, can't swap left (1 is fixed at start). 
                            # Assuming non-circular swap for the purpose of sorting to target (target usually 1 2 ...).
                            break
                except ValueError:
                    raise TestFailure(f"Command {cmd} not found in current sequence {current}")
            
            if current != target_list:
                 raise TestFailure(f"Resulting sequence {current} does not match target {target_list}")
            cocotb.log.info(f"Verified: Sequence matches target after {len(commands)} commands.")

        else:
             raise TestFailure("No commands generated")
