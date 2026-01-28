import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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
    return min((1 << bits) - 1, max(0, v))

# --- Main Test ---
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_scheduled_slides(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clk_period = 10  # ns
        clock = Clock(dut.clk, clk_period, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test Cases (Scaled)
    # Original Sample 1: [10000, 400000, 500000, 900000] -> 12 cookies (3*4)
    # Scaled: Divide times by ~10000 to fit 16 bits. 10000->1, 400000->40, 500000->50, 900000->90
    # Durations: 20, 30, 40. Rewards: 1, 3, 4.
    # Gap 39, 10, 40. Gaps > 40 needed for max reward of 4 per job.
    # 1->40 (gap 39, can take small: reward 1)
    # 40->50 (gap 10, can't take any full duration)
    # 50->90 (gap 40, can take small: reward 1)
    # Max reward 1+1=2? Wait, sample output 12 implies 3 jobs * 4 cookies (humongous).
    # Original times: 10000, 400000, 500000, 900000.
    # 10000 + 400000 = 410000. Next offer 500000. Gap 90000. OK for 400000.
    # 400000 + 400000 = 800000. Next offer 900000. Gap 100000. OK.
    # 10000 + 400000 = 410000. Next offer 500000. Gap 90000. OK.
    # Actually, let's stick to the literal sample logic but scaled.
    # Sample 1 Output 12 (3 jobs * 4 cookies).
    # 3 jobs means we picked 1st, 3rd, 4th.
    # 1st (10000) + 400000 = 410000. 3rd is 500000 (Gap 90000). OK.
    # 3rd (500000) + 400000 = 900000. 4th is 900000 (Gap 0). OK.
    # 4th (900000) + 400000 = 1.3M. End of year OK.
    
    # Scaled Input 1:
    # Times: 1, 40, 50, 90
    # Durations: 20, 30, 40.
    # 1->40 (Gap 39). Can take Small(20) -> end 21. Next 50 is > 21. OK.
    # 40->50 (Gap 10). Can't take any.
    # 50->90 (Gap 40). Can take Small(20) -> end 70. OK.
    # 1 + 50 = 51. 90 > 51. OK.
    # 1 -> 40 (Small). 50 -> 90 (Small). Total 2 cookies? No.
    # Let's use the scaled input that matches the logic exactly.
    # To get 12 cookies (3*4), we need gaps >= 40.
    # Times: 0, 40, 80. Gaps 40, 40. Output 12.
    
    test_cases = [
        ([0, 40, 80], 12, "Ideal 3 jobs"),
        ([1, 41, 81], 12, "Shifted 3 jobs"),
        ([0, 10, 20], 1, "Tight, only 1 job fits"),
        ([0, 100], 8, "2 jobs, large"),
        ([0, 30], 4, "1 job large vs 1 small+medium")
    ]

    for (times, expected, desc) in test_cases:
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        N = len(times)
        
        # Set N
        if has_signal(dut, 'N'):
            dut.N.value = N
        
        # Set Times (Assuming individual offer_time_0 to offer_time_15)
        for i in range(16):
            if i < N:
                val = clamp_to_width(times[i], 16)
            else:
                val = 0
            
            port_name = f'offer_time_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = val
            # Fallback for packed array (less common in simple setups but handled)
            elif has_signal(dut, 'offer_times'):
                 try:
                     dut.offer_times[i].value = val
                 except Exception:
                     pass

        if has_signal(dut, 'offers_valid'):
            dut.offers_valid.value = 1

        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            cycles = 0
            max_cycles = 1000
            done_found = False
            
            if has_signal(dut, 'done'):
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_found = True
                        break
                if not done_found:
                    raise TestFailure(f"Timeout waiting for done on test '{desc}'")
            else:
                await Timer(500, units='ns') # No done signal, just wait for propagation
        else:
            await Timer(100, units='ns')

        # Check Result
        result_signal = getattr(dut, 'result', None)
        if result_signal is None:
             # Try alternative names if convention used
             for name in ['result', 'max_cookies', 'output']:
                 if has_signal(dut, name):
                     result_signal = getattr(dut, name)
                     break

        if result_signal:
            result_val = int(result_signal.value)
            if result_val != expected:
                raise TestFailure(f"Test '{desc}' failed: Expected {expected}, got {result_val}")
            else:
                cocotb.log.info(f"Test '{desc}' passed. Result: {result_val}")
        else:
            raise TestFailure("Result signal not found in module")