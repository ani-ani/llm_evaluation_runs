module world_counter (input clk, input rst_n, input start, input [5:0] n, input [5:0] m, output reg [63:0] result, output reg done);
localparam MOD = 1000000007;
localparam IDLE = 3'd0, INIT = 3'd1, PREPARE_INVERSE = 3'd2, DP_LOOP = 3'd3, FINISHED = 3'd4;

reg [63:0] f [0:50][0:50];
reg [63:0] s [0:50][0:50];

function reg [63:0] get_inv;
    input integer i;
    reg [63:0] inv_i;
    case(i)
        1: inv_i = 1;
        2: inv_i = 500000004;
        3: inv_i = 333333336;
        4: inv_i = 250000002;
        5: inv_i = 400000003;
        6: inv_i = 166666668;
        7: inv_i = 142857144;
        8: inv_i = 125000001;
        9: inv_i = 111111112;
        10: inv_i = 700000005;
        11: inv_i = 227272728;
        12: inv_i = 83333334;
        13: inv_i = 76923077;
        14: inv_i = 64285715;
        15: inv_i = 66666667;
        16: inv_i = 562500004;
        17: inv_i = 176470588;
        18: inv_i = 55555556;
        19: inv_i = 47368421;
        20: inv_i = 50000000;
        21: inv_i = 38095238;
        22: inv_i = 22727273;
        23: inv_i = 17391304;
        24: inv_i = 41666667;
        25: inv_i = 28000000;
        26: inv_i = 19230769;
        27: inv_i = 14814815;
        28: inv_i = 12857143;
        29: inv_i = 34482759;
        30: inv_i = 33333334;
        31: inv_i = 32258065;
        32: inv_i = 28125000;
        33: inv_i = 30303030;
        34: inv_i = 26470588;
        35: inv_i = 28571429;
        36: inv_i = 27777778;
        37: inv_i = 27027027;
        38: inv_i = 26315789;
        39: inv_i = 25641026;
        40: inv_i = 25000000;
        41: inv_i = 24390244;
        42: inv_i = 23809524;
        43: inv_i = 23255814;
        44: inv_i = 22727273;
        45: inv_i = 22222222;
        46: inv_i = 21739130;
        47: inv_i = 21276596;
        48: inv_i = 20833333;
        49: inv_i = 20408163;
        50: inv_i = 20000000;
        default: inv_i = 0;
    endcase
    return inv_i;
endfunction

reg [2:0] state, next_state;
reg [63:0] result_reg;
reg done_reg;
reg [7:0] node_counter, cut_counter;
reg [63:0] tmp, cnt, product;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        result_reg <= 0;
        done_reg <=0;
        f <= 0;
        s <= 0;
        node_counter <=0;
        cut_counter <=0;
        tmp <=0;
        cnt <=0;
        product <=0;
    end else begin
        state <= next_state;
        if (state == INIT) begin
            f[0][0] <= 1;
            s[0][0] <= 1;
        end
        if (state == FINISHED) begin
            done_reg <= 1;
            result_reg <= f[50][49];
        end
    end
end

always @(*) begin
    next_state = state;
    if (state == IDLE && start) begin
        next_state = INIT;
    end else if (state == INIT) begin
        next_state = PREPARE_INVERSE;
    end else if (state == PREPARE_INVERSE) begin
        next_state = DP_LOOP;
    end else if (state == DP_LOOP) begin
        if (node_counter > 50 || cut_counter > 50) begin
            next_state = FINISHED;
        end
    end
end

always @(posedge clk) begin
    if (state == DP_LOOP) begin
        if (node_counter < 50) begin
            node_counter <= node_counter + 1;
            cut_counter <= 0;
        end else if (cut_counter < 50) begin
            cut_counter <= cut_counter + 1;
        end
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule