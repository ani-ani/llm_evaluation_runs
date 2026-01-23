module cups_and_key_solver (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire last_in,
    input wire [63:0] a_in,
    output reg [31:0] result_x,
    output reg [31:0] result_y,
    output reg done
);

localparam MOD = 1000000007;
localparam MOD_ACC = 1000000006;
localparam INVERSE_3 = 333333336;
localparam IDLE = 3'd0;
localparam PROCESSING = 3'd1;
localparam CALC_EXP = 3'd2;
localparam CALC_N = 3'd3;
localparam DONE_STATE = 3'd4;

reg [31:0] mod_acc;
reg [31:0] X;
reg [31:0] current_res;
reg [31:0] current_base;
reg [31:0] current_exp;
reg [31:0] iter_cnt;
reg [31:0] result_x_reg;
reg [31:0] result_y_reg;
reg [2:0] state;
reg parity_flag;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mod_acc <= 1;
        X <= 0;
        current_res <= 0;
        current_base <= 0;
        current_exp <= 0;
        iter_cnt <= 0;
        result_x_reg <= 0;
        result_y_reg <= 0;
        state <= IDLE;
        parity_flag <= 0;
        done <= 0;
    end else begin
        if (state == IDLE) begin
            if (valid_in) begin
                if (last_in) begin
                    mod_acc <= 1;
                    state <= CALC_EXP;
                end
            end
        end
    end
end

assign result_x = result_x_reg;
assign result_y = result_y_reg;
assign done = done;

endmodule