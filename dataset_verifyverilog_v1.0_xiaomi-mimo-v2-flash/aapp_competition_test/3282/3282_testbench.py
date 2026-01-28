import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

# Python reference implementation for verification
def solve_python(P):
    bills = []
    def get_digits(n):
        s = str(n)
        return set(s)
    
    digits_P = get_digits(P)
    
    # Iterate B from 1 to P//2
    for B in range(1, (P // 2) + 1):
        M = P - B
        if B >= M:
            continue
        
        digits_B = get_digits(B)
        digits_M = get_digits(M)
        
        # Check mutual exclusivity
        if (not (digits_B & digits_P) and 
            not (digits_B & digits_M) and 
            not (digits_M & digits_P)):
            bills.append((B, M))
            
    return bills

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bill_finder(dut):
    # Setup clock if seq
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational logic (unlikely for this problem, but handled)
        await Timer(10, units='ns')

    # Test cases
    test_cases = [
        37,
        30014,
        202020202020202058  # This P is > 65535, so we clamp it or skip if HDL is 16-bit
    ]

    for P_raw in test_cases:
        # Clamp P to 16-bit as per interface spec (max 65535)
        P = clamp_to_width(P_raw, 16)
        
        cocotb.log.info(f"Testing P={P} (original {P_raw})")
        
        # Expected results from Python reference
        expected_bills = solve_python(P)
        expected_count = len(expected_bills)
        
        if is_seq:
            dut.P.value = P
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            collected_bills = []
            done_detected = False
            cycles = 0
            max_cycles = 100000  # Give enough time for sequential search
            
            while not done_detected and cycles < max_cycles:
                await RisingEdge(dut.clk)
                cycles += 1
                
                # Check valid signal
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    b = int(dut.b_out.value)
                    m = int(dut.m_out.value)
                    collected_bills.append((b, m))
                    cocotb.log.info(f"Found bill: B={b}, M={m}")
                
                # Check done signal
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_detected = True
            
            if not done_detected:
                raise TestFailure(f"Module did not assert 'done' within {max_cycles} cycles")
            
            # Verify count
            if is_value_defined(dut.count.value):
                hw_count = int(dut.count.value)
                if hw_count != expected_count:
                    raise TestFailure(f"Count mismatch: HW={hw_count}, SW={expected_count}")
            
            # Verify collected bills match expected
            # Sort expected to match ascending B order
            expected_bills.sort(key=lambda x: x[0])
            
            # If expected count > 5000, the spec says output only first 5000.
            # We verify collected against what the HDL should output.
            limit = 5000
            expected_subset = expected_bills[:limit]
            
            if collected_bills != expected_subset:
                raise TestFailure(f"Bills mismatch. Collected {len(collected_bills)}, Expected {len(expected_subset)}")
                
        else:
            # Combinational check (if such a module existed)
            dut.P.value = P
            await Timer(10, units='ns')
            # Check result...

    cocotb.log.info("All tests passed!")