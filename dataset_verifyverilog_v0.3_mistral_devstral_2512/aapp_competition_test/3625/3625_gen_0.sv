module TreeHarvester #(
    parameter N = 2,
    parameter DATA_WIDTH = 8,
    parameter I_WIDTH = 8,
    parameter YEAR_WIDTH = 12,
    parameter POP_WIDTH = 24
)(
    input clk,
    input rst_n,
    input start,
    input [1:0] valid_count,
    input [DATA_WIDTH-1:0] S_0, B_0, Y_0,
    input [I_WIDTH-1:0] I_0,
    input [DATA_WIDTH-1:0] S_1, B_1, Y_1,
    input [I_WIDTH-1:0] I_1,
    output reg [POP_WIDTH-1:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PREPARE_T = 3'd2;
    localparam [2:0] COMPUTE_TOTAL = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] INCREMENT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state;
    reg [0:0] i_idx;
    reg [0:0] k_idx;
    reg phase;
    reg [YEAR_WIDTH-1:0] t;
    reg [POP_WIDTH-1:0] total;
    reg [POP_WIDTH-1:0] max_total;

    reg [DATA_WIDTH-1:0] latched_S_0, latched_S_1;
    reg [DATA_WIDTH-1:0] latched_B_0, latched_B_1;
    reg [DATA_WIDTH-1:0] latched_Y_0, latched_Y_1;
    reg [I_WIDTH-1:0] latched_I_0, latched_I_1;

    wire [POP_WIDTH-1:0] pop_k;
    wire [YEAR_WIDTH-1:0] diff_t_B = t - (k_idx == 1'b0 ? latched_B_0 : latched_B_1);
    wire [YEAR_WIDTH-1:0] diff_t_BY = t - (k_idx == 1'b0 ? latched_B_0 : latched_B_1) - (k_idx == 1'b0 ? latched_Y_0 : latched_Y_1);
    wire signed [POP_WIDTH:0] inc_pop = $signed({1'b0, (k_idx == 1'b0 ? latched_S_0 : latched_S_1)}) + 
                                         $signed({1'b0, (k_idx == 1'b0 ? latched_I_0 : latched_I_1)}) * $signed({1'b0, diff_t_B});
    wire signed [POP_WIDTH:0] dec_pop = $signed({1'b0, (k_idx == 1'b0 ? latched_I_0 : latched_I_1)}) * $signed({1'b0, (k_idx == 1'b0 ? latched_Y_0 : latched_Y_1)}) -
                                         $signed({1'b0, (k_idx == 1'b0 ? latched_I_0 : latched_I_1)}) * $signed({1'b0, diff_t_BY});
    wire signed [POP_WIDTH:0] peak_pop = $signed({1'b0, (k_idx == 1'b0 ? latched_S_0 : latched_S_1)}) +
                                         $signed({1'b0, (k_idx == 1'b0 ? latched_I_0 : latched_I_1)}) * $signed({1'b0, (k_idx == 1'b0 ? latched_Y_0 : latched_Y_1)});

    assign pop_k = (t < (k_idx == 1'b0 ? latched_B_0 : latched_B_1)) ? 24'd0 :
                   (t <= (k_idx == 1'b0 ? latched_B_0 : latched_B_1) + (k_idx == 1'b0 ? latched_Y_0 : latched_Y_1)) ? inc_pop[POP_WIDTH-1:0] :
                   (dec_pop > 0) ? dec_pop[POP_WIDTH-1:0] : 24'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_idx <= 1'b0;
            k_idx <= 1'b0;
            phase <= 1'b0;
            t <= 12'd0;
            total <= 24'd0;
            max_total <= 24'd0;
            latched_S_0 <= 8'd0;
            latched_B_0 <= 8'd0;
            latched_Y_0 <= 8'd0;
            latched_I_0 <= 8'd0;
            latched_S_1 <= 8'd0;
            latched_B_1 <= 8'd0;
            latched_Y_1 <= 8'd0;
            latched_I_1 <= 8'd0;
            result <= 24'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                INIT: begin
                    latched_S_0 <= S_0;
                    latched_B_0 <= B_0;
                    latched_Y_0 <= Y_0;
                    latched_I_0 <= I_0;
                    latched_S_1 <= S_1;
                    latched_B_1 <= B_1;
                    latched_Y_1 <= Y_1;
                    latched_I_1 <= I_1;
                    state <= PREPARE_T;
                end
                PREPARE_T: begin
                    t <= (phase == 1'b0) ? (i_idx == 1'b0 ? latched_B_0 : latched_B_1) : 
                                          ((i_idx == 1'b0 ? latched_B_0 : latched_B_1) + (i_idx == 1'b0 ? latched_Y_0 : latched_Y_1));
                    total <= 24'd0;
                    k_idx <= 1'b0;
                    state <= COMPUTE_TOTAL;
                end
                COMPUTE_TOTAL: begin
                    if (k_idx < valid_count) begin
                        total <= total + pop_k;
                        k_idx <= k_idx + 1'b1;
                    end else begin
                        if (total > max_total) begin
                            max_total <= total;
                        end
                        state <= INCREMENT;
                    end
                end
                INCREMENT: begin
                    if (phase == 1'b0) begin
                        phase <= 1'b1;
                    end else begin
                        phase <= 1'b0;
                        i_idx <= i_idx + 1'b1;
                    end
                    if (phase == 1'b1 && i_idx + 1'b1 >= valid_count) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= PREPARE_T;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_total;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule