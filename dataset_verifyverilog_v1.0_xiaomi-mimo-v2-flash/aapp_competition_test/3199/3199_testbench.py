import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, MAX_L, CLK_NS, MAX_CYCLES = 11, 1024, 10, 500000

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

def gcd(a, b):
    while b: a, b = b, a % b
    return a

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_vaults(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 1, 3, 2, 2, 5),
        (2, 3, 4, 0, 16, 8),
        (7, 11, 1024, 6723409, 2301730, 9974861)  # L scaled down
    ]
    
    passed = 0
    for a, b, l, exp_ins, exp_sec, exp_sup in test_cases:
        dut.A.value = a
        dut.B.value = b
        dut.L.value = l
        
        cocotb.log.info(f"Test: A={a}, B={b}, L={l}")
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            cycles = 0
            while cycles < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycles += 1
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            if cycles >= MAX_CYCLES:
                cocotb.log.error(f"Timeout after {MAX_CYCLES} cycles")
                continue
        else:
            await Timer(1000, units='ns')
        
        if not all([has_signal(dut, 'insecure_cnt'), has_signal(dut, 'secure_cnt'), has_signal(dut, 'supersecure_cnt')]):
            cocotb.log.error("Missing output signals")
            continue
        
        if not is_value_defined(dut.insecure_cnt.value):
            cocotb.log.error("insecure_cnt undefined")
            continue
        
        ins = int(dut.insecure_cnt.value)
        sec = int(dut.secure_cnt.value)
        sup = int(dut.supersecure_cnt.value)
        
        cocotb.log.info(f"Result: INS={ins}, SEC={sec}, SUP={sup}")
        
        if ins != exp_ins or sec != exp_sec or sup != exp_sup:
            cocotb.log.error(f"FAIL: Expected INS={exp_ins}, SEC={exp_sec}, SUP={exp_sup}")
        else:
            passed += 1
    
    if passed < len(test_cases):
        raise TestFailure(f"Only {passed}/{len(test_cases)} tests passed")