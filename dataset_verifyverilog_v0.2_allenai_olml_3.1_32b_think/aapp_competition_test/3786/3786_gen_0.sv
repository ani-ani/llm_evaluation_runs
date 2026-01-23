module apple_collector (
    input clk,
    input rst_n,
    input start,
    input [3:0] p_addr,
    input [3:0] p_data,
    input p_write,
    output reg [3:0] result,
    output reg done
);

reg [3:0] parent_mem [14:0];
reg [3:0] depth_mem [15:0];
reg [3:0] count_mem [7:0];
reg [2:0] state;

localparam IDLE = 3'b000;
localparam CALC_DEPTH = 3'b001;
localparam COUNT_LAYER = 3'b010;
localparam SUM_PARITY = 3'b011;
localparam DONE = 3'b100;

reg [3:0] node_counter;
reg [3:0] node_idx;
reg [2:0] depth_idx;
reg [3:0] sum_result;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        node_counter <= 4'd2;
        depth_mem[0] <= 4'd0;
        node_idx <= 4'd0;
        depth_idx <= 3'b0;
        sum_result <= 4'd0;
        done <= 1'b0;
        count_mem[0] <= 4'd0;
        count_mem[1] <= 4'd0;
        count_mem[2] <= 4'd0;
        count_mem[3] <= 4'd0;
        count_mem[4] <= 4'd0;
        count_mem[5] <= 4'd0;
        count_mem[6] <= 4'd0;
        count_mem[7] <= 4'd0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= CALC_DEPTH;
                end
            end
            CALC_DEPTH: begin
                if (node_counter <= 16) begin
                    if (node_counter >= 2) begin
                        depth_mem[node_counter - 1] <= compute_depth(node_counter);
                    end
                    node_counter <= node_counter + 1;
                end else begin
                    state <= COUNT_LAYER;
                    node_counter <= 4'd0;
                end
            end
            COUNT_LAYER: begin
                if (node_idx == 4'd0) begin
                    node_idx <= 4'd1;
                end else if (node_idx <= 4'd16) begin
                    int current_depth = depth_mem[node_idx - 1];
                    if (current_depth < 8) begin
                        count_mem[current_depth] <= count_mem[current_depth] + 1;
                    end
                    node_idx <= node_idx + 1;
                end else begin
                    state <= SUM_PARITY;
                    node_idx <= 4'd0;
                end
            end
            SUM_PARITY: begin
                if (depth_idx < 3'd8) begin
                    sum_result <= sum_result + (count_mem[depth_idx] & 1);
                    depth_idx <= depth_idx + 1;
                end else begin
                    result <= sum_result;
                    done <= 1'b1;
                    state <= DONE;
                end
            end
            DONE: begin
                // Stay in done state
            end
        endcase
    end
end

function automatic int compute_depth;
    input int node;
    automatic int depth = 0;
    automatic int current = node;
    while (current != 1) begin
        if (current < 2) begin
            break;
        end
        current = parent_mem[current - 2];
        depth = depth + 1;
    end
    return depth;
endfunction