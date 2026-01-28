import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def rev_python(num):
    rev_num = 0
    temp = num
    while temp > 0:
        rev_num = (rev_num * 10 + temp % 10)
        temp = temp // 10
    return rev_num

def check_python(n):
    return (2 * rev_python(n) == n + 1)

async def write_input(dut, value):
    dut.n.value = clamp_to_width(value, DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_reverse(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic - no clock/reset
        await Timer(100, units='ns')
    
    test_cases = [
        (70, False, "70: reverse 7, 2*7=14 != 71"),
        (23, False, "23: reverse 32, 2*32=64 != 24"),
        (73, True, "73: reverse 37, 2*37=74 == 74"),
        (0, True, "0: reverse 0, 2*0=0 == 1? No -> 0"),
        (1, False, "1: reverse 1, 2*1=2 != 2? No -> 2"),
        (2, True, "2: reverse 2, 2*2=4 == 3? No -> 3"),
        (3, False, "3: reverse 3, 2*3=6 == 4? No -> 4"),
        (9, False, "9: reverse 9, 2*9=18 == 10? No -> 10"),
        (11, False, "11: reverse 11, 2*11=22 == 12? No -> 12"),
        (12, True, "12: reverse 21, 2*21=42 == 13? No -> 13"),
        (21, False, "21: reverse 12, 2*12=24 == 22? No -> 22"),
        (24, True, "24: reverse 42, 2*42=84 == 25? No -> 25"),
        (42, False, "42: reverse 24, 2*24=48 == 43? No -> 43"),
        (43, True, "43: reverse 34, 2*34=68 == 44? No -> 44"),
        (34, False, "34: reverse 43, 2*43=86 == 35? No -> 35"),
        (35, False, "35: reverse 53, 2*53=106 == 36? No -> 36"),
        (53, False, "53: reverse 35, 2*35=70 == 54? No -> 54"),
        (54, True, "54: reverse 45, 2*45=90 == 55? No -> 55"),
        (45, False, "45: reverse 54, 2*54=108 == 46? No -> 46"),
        (46, False, "46: reverse 64, 2*64=128 == 47? No -> 47"),
        (64, False, "64: reverse 46, 2*46=92 == 65? No -> 65"),
        (65, False, "65: reverse 56, 2*56=112 == 66? No -> 66"),
        (56, False, "56: reverse 65, 2*65=130 == 57? No -> 57"),
        (57, False, "57: reverse 75, 2*75=150 == 58? No -> 58"),
        (75, False, "75: reverse 57, 2*57=114 == 76? No -> 76"),
        (76, False, "76: reverse 67, 2*67=134 == 77? No -> 77"),
        (67, False, "67: reverse 76, 2*76=152 == 68? No -> 68"),
        (68, False, "68: reverse 86, 2*86=172 == 69? No -> 69"),
        (86, False, "86: reverse 68, 2*68=136 == 87? No -> 87"),
        (87, False, "87: reverse 78, 2*78=156 == 88? No -> 88"),
        (78, False, "78: reverse 87, 2*87=174 == 79? No -> 79"),
        (79, False, "79: reverse 97, 2*97=194 == 80? No -> 80"),
        (97, False, "97: reverse 79, 2*79=158 == 98? No -> 98"),
        (98, False, "98: reverse 89, 2*89=178 == 99? No -> 99"),
        (89, False, "89: reverse 98, 2*98=196 == 90? No -> 90"),
        (90, False, "90: reverse 9, 2*9=18 == 91? No -> 91"),
        (91, False, "91: reverse 19, 2*19=38 == 92? No -> 92"),
        (19, False, "19: reverse 91, 2*91=182 == 20? No -> 20"),
        (20, False, "20: reverse 2, 2*2=4 == 21? No -> 21"),
        (21, False, "21: reverse 12, 2*12=24 == 22? No -> 22"),
        (22, False, "22: reverse 22, 2*22=44 == 23? No -> 23"),
        (23, False, "23: reverse 32, 2*32=64 == 24? No -> 24"),
        (24, True, "24: reverse 42, 2*42=84 == 25? No -> 25"),
        (25, False, "25: reverse 52, 2*52=104 == 26? No -> 26"),
        (26, False, "26: reverse 62, 2*62=124 == 27? No -> 27"),
        (27, False, "27: reverse 72, 2*72=144 == 28? No -> 28"),
        (28, False, "28: reverse 82, 2*82=164 == 29? No -> 29"),
        (29, False, "29: reverse 92, 2*92=184 == 30? No -> 30"),
        (30, False, "30: reverse 3, 2*3=6 == 31? No -> 31"),
        (31, False, "31: reverse 13, 2*13=26 == 32? No -> 32"),
        (32, False, "32: reverse 23, 2*23=46 == 33? No -> 33"),
        (33, False, "33: reverse 33, 2*33=66 == 34? No -> 34"),
        (34, False, "34: reverse 43, 2*43=86 == 35? No -> 35"),
        (35, False, "35: reverse 53, 2*53=106 == 36? No -> 36"),
        (36, False, "36: reverse 63, 2*63=126 == 37? No -> 37"),
        (37, False, "37: reverse 73, 2*73=146 == 38? No -> 38"),
        (38, False, "38: reverse 83, 2*83=166 == 39? No -> 39"),
        (39, False, "39: reverse 93, 2*93=186 == 40? No -> 40"),
        (40, False, "40: reverse 4, 2*4=8 == 41? No -> 41"),
        (41, False, "41: reverse 14, 2*14=28 == 42? No -> 42"),
        (42, False, "42: reverse 24, 2*24=48 == 43? No -> 43"),
        (43, True, "43: reverse 34, 2*34=68 == 44? No -> 44"),
        (44, False, "44: reverse 44, 2*44=88 == 45? No -> 45"),
        (45, False, "45: reverse 54, 2*54=108 == 46? No -> 46"),
        (46, False, "46: reverse 64, 2*64=128 == 47? No -> 47"),
        (47, False, "47: reverse 74, 2*74=148 == 48? No -> 48"),
        (48, False, "48: reverse 84, 2*84=168 == 49? No -> 49"),
        (49, False, "49: reverse 94, 2*94=188 == 50? No -> 50"),
        (50, False, "50: reverse 5, 2*5=10 == 51? No -> 51"),
        (51, False, "51: reverse 15, 2*15=30 == 52? No -> 52"),
        (52, False, "52: reverse 25, 2*25=50 == 53? No -> 53"),
        (53, False, "53: reverse 35, 2*35=70 == 54? No -> 54"),
        (54, True, "54: reverse 45, 2*45=90 == 55? No -> 55"),
        (55, False, "55: reverse 55, 2*55=110 == 56? No -> 56"),
        (56, False, "56: reverse 65, 2*65=130 == 57? No -> 57"),
        (57, False, "57: reverse 75, 2*75=150 == 58? No -> 58"),
        (58, False, "58: reverse 85, 2*85=170 == 59? No -> 59"),
        (59, False, "59: reverse 95, 2*95=190 == 60? No -> 60"),
        (60, False, "60: reverse 6, 2*6=12 == 61? No -> 61"),
        (61, False, "61: reverse 16, 2*16=32 == 62? No -> 62"),
        (62, False, "62: reverse 26, 2*26=52 == 63? No -> 63"),
        (63, False, "63: reverse 36, 2*36=72 == 64? No -> 64"),
        (64, False, "64: reverse 46, 2*46=92 == 65? No -> 65"),
        (65, False, "65: reverse 56, 2*56=112 == 66? No -> 66"),
        (66, False, "66: reverse 66, 2*66=132 == 67? No -> 67"),
        (67, False, "67: reverse 76, 2*76=152 == 68? No -> 68"),
        (68, False, "68: reverse 86, 2*86=172 == 69? No -> 69"),
        (69, False, "69: reverse 96, 2*96=192 == 70? No -> 70"),
        (70, False, "70: reverse 7, 2*7=14 == 71? No -> 71"),
        (71, False, "71: reverse 17, 2*17=34 == 72? No -> 72"),
        (72, False, "72: reverse 27, 2*27=54 == 73? No -> 73"),
        (73, True, "73: reverse 37, 2*37=74 == 74? Yes -> 74"),
        (74, False, "74: reverse 47, 2*47=94 == 75? No -> 75"),
        (75, False, "75: reverse 57, 2*57=114 == 76? No -> 76"),
        (76, False, "76: reverse 67, 2*67=134 == 77? No -> 77"),
        (77, False, "77: reverse 77, 2*77=154 == 78? No -> 78"),
        (78, False, "78: reverse 87, 2*87=174 == 79? No -> 79"),
        (79, False, "79: reverse 97, 2*97=194 == 80? No -> 80"),
        (80, False, "80: reverse 8, 2*8=16 == 81? No -> 81"),
        (81, False, "81: reverse 18, 2*18=36 == 82? No -> 82"),
        (82, False, "82: reverse 28, 2*28=56 == 83? No -> 83"),
        (83, False, "83: reverse 38, 2*38=76 == 84? No -> 84"),
        (84, False, "84: reverse 48, 2*48=96 == 85? No -> 85"),
        (85, False, "85: reverse 58, 2*58=116 == 86? No -> 86"),
        (86, False, "86: reverse 68, 2*68=136 == 87? No -> 87"),
        (87, False, "87: reverse 78, 2*78=156 == 88? No -> 88"),
        (88, False, "88: reverse 88, 2*88=176 == 89? No -> 89"),
        (89, False, "89: reverse 98, 2*98=196 == 90? No -> 90"),
        (90, False, "90: reverse 9, 2*9=18 == 91? No -> 91"),
        (91, False, "91: reverse 19, 2*19=38 == 92? No -> 92"),
        (92, False, "92: reverse 29, 2*29=58 == 93? No -> 93"),
        (93, False, "93: reverse 39, 2*39=78 == 94? No -> 94"),
        (94, False, "94: reverse 49, 2*49=98 == 95? No -> 95"),
        (95, False, "95: reverse 59, 2*59=118 == 96? No -> 96"),
        (96, False, "96: reverse 69, 2*69=138 == 97? No -> 97"),
        (97, False, "97: reverse 79, 2*79=158 == 98? No -> 98"),
        (98, False, "98: reverse 89, 2*89=178 == 99? No -> 99"),
        (99, False, "99: reverse 99, 2*99=198 == 100? No -> 100"),
    ]
    
    passed = failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n})")
        try:
            await write_input(dut, n)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            exp_val = 1 if expected else 0
            
            if result != exp_val:
                raise TestFailure(f"Expected {exp_val}, got {result} for n={n}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
