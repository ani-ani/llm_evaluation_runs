import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 11
N_WIDTH = 7
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10

# Helper Functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Main Test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_weather_prediction(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, temperatures, expected_result)
    test_cases = [
        (5, [10,5,0,-5,-10], -15),
        (4, [1,1,1,1], 1),
        (3, [5,1,-5], -5),
        (2, [900,1000], 1100),
        (2, [1,2], 3),
        (3, [2,5,8], 11),
        (4, [4,1,-2,-5], -8),
        (10, [-1000,-995,-990,-985,-980,-975,-970,-965,-960,-955], -950),
        (11, [-1000,-800,-600,-400,-200,0,200,400,600,800,1000], 1200),
        (31, [1000,978,956,934,912,890,868,846,824,802,780,758,736,714,692,670,648,626,604,582,560,538,516,494,472,450,428,406,384,362,340], 318),
        (5, [1000,544,88,-368,-824], -1280),
        (100, [0]*100, 0),
        (33, [456,411,366,321,276,231,186,141,96,51,6,-39,-84,-129,-174,-219,-264,-309,-354,-399,-444,-489,-534,-579,-624,-669,-714,-759,-804,-849,-894,-939,-984], -1029),
        (77, [-765,-742,-719,-696,-673,-650,-627,-604,-581,-558,-535,-512,-489,-466,-443,-420,-397,-374,-351,-328,-305,-282,-259,-236,-213,-190,-167,-144,-121,-98,-75,-52,-29,-6,17,40,63,86,109,132,155,178,201,224,247,270,293,316,339,362,385,408,431,454,477,500,523,546,569,592,615,638,661,684,707,730,753,776,799,822,845,868,891,914,937,960,983], 1006),
        (3, [2,4,8], 8),
        (4, [4,1,-3,-5], -5),
        (10, [-1000,-995,-990,-984,-980,-975,-970,-965,-960,-955], -955),
        (11, [-999,-800,-600,-400,-200,0,200,400,600,800,1000], 1000),
        (51, [-9,10,30,50,70,90,110,130,150,170,190,210,230,250,270,290,310,330,350,370,390,410,430,450,470,490,510,530,550,570,590,610,630,650,670,690,710,730,750,770,790,810,830,850,870,890,910,930,950,970,990], 990),
        (100, [10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,100,102,104,106,108,110,112,114,116,118,120,122,124,126,128,130,132,134,136,138,140,142,144,146,148,150,152,154,156,158,160,162,164,166,168,170,172,174,176,178,180,182,184,186,188,190,192,194,196,198,200,202,204,206,207], 207),
        (2, [1000,1000], 1000),
        (2, [-1000,1000], 3000),
        (2, [1000,-1000], -3000),
        (2, [-1000,-1000], -1000),
        (100, [-85,-80,-76,-72,-68,-64,-60,-56,-52,-48,-44,-40,-36,-32,-28,-24,-20,-16,-12,-8,-4,0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64,68,72,76,80,84,88,92,96,100,104,108,112,116,120,124,128,132,136,140,144,148,152,156,160,164,168,172,176,180,184,188,192,196,200,204,208,212,216,220,224,228,232,236,240,244,248,252,256,260,264,268,272,276,280,284,288,292,296,300,304,308,312], 312)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, temps, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, expected={expected}")
        
        try:
            # Set n
            dut.n.value = n
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed temperatures sequentially
            for temp in temps:
                dut.data_in.value = from_signed(temp, DATA_WIDTH)
                await RisingEdge(dut.clk)
            
            # Wait for done
            if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                raise TestFailure(f"Done not asserted")
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined")
            
            result = to_signed(int(dut.result.value), RESULT_WIDTH)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait for one cycle to return to IDLE
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")