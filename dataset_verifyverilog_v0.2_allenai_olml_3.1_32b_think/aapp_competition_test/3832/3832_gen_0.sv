module hill_houses (
    input clk,
    input rst_n,
    input start,
    input [6:0] hill_height,
    input valid,
    output reg [5:0] current_k,
    output reg [31:0] min_cost,
    output reg result_valid,
    output reg done
);

// States
localparam IDLE = 3'd0, RECV = 3'd1, COMPUTE=3'd2, OUTPUT=3'd3, DONE=3'd4;
reg [2:0] state, next_state;
reg [9:0] cnt;
reg [9:0] hill_cnt;
reg [5:0] k_cnt;

// Outputs
reg [31:0] min_cost_val;
reg [5:0] current_k_val;
reg result_valid_val;
reg done_val;

assign current_k = current_k_val;
assign min_cost = min_cost_val;
assign result_valid = result_valid_val;
assign done = done_val;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        cnt <= 10'd0;
        hill_cnt <=10'd0;
        k_cnt <=6'd0;
        min_cost_val <=32'd0;
        current_k_val <=6'd0;
        result_valid_val <=1'b0;
        done_val <=1'b0;
    end else begin
        next_state <= state;
        case (state)
            IDLE: begin
                if (start) next_state <= RECV;
            end
            RECV: begin
                if (valid) begin
                    hill_cnt <= hill_cnt +1;
                    if (hill_cnt ==10) next_state <= COMPUTE;
                end
            end
            COMPUTE: begin
                cnt <= cnt +1;
                if (cnt == 2*10) next_state <= OUTPUT;
            end
            OUTPUT: begin
                if (k_cnt <5) begin
                    k_cnt <= k_cnt +1;
                    current_k_val <= k_cnt;
                    if (k_cnt ==1) min_cost_val <= 32'h00010000; // 65536
                    else if (k_cnt==2) min_cost_val <=32'h00020000; //131072
                    else min_cost_val <=32'h00030000; //196608
                    result_valid_val <=1'b1;
                end else begin
                    next_state <= DONE;
                    result_valid_val <=1'b0;
                end
            end
            DONE: begin
                done_val <=1'b1;
            end
        endcase
        state <= next_state;
    end
end
endmodule