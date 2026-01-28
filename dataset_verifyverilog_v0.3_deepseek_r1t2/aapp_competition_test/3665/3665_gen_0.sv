module LossySorter #(
    parameter N = 2,          
    parameter M = 3,          
    parameter DIGIT_WIDTH = 4
)(
    input clk,
    input rst_n,
    input start,
    input [N-1:0][M*DIGIT_WIDTH-1:0] numbers_in,
    output reg [N-1:0][M*DIGIT_WIDTH-1:0] numbers_out,
    output reg done
);

localparam STATE_IDLE = 2'd0;
localparam STATE_COMPUTE = 2'd1;
localparam STATE_OUTPUT = 2'd2;
localparam STATE_DONE = 2'd3;

reg [1:0] current_state;
reg [N-2:0] state_vector;
reg [M-1:0] digit_idx;
reg [15:0] total_cost;
reg [N-1:0][M*DIGIT_WIDTH-1:0] temp_numbers;

wire [DIGIT_WIDTH-1:0] orig_d0, orig_d1;
reg [DIGIT_WIDTH-1:0] new_d0, new_d1;
reg [1:0] cost_per_digit;
reg new_state_bit;

assign orig_d0 = numbers_in[0][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH];
assign orig_d1 = numbers_in[1][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH];

always @(*) begin
    if (state_vector[0] == 1'b1) begin
        new_d0 = orig_d0;
        new_d1 = orig_d1;
        cost_per_digit = 2'd0;
        new_state_bit = 1'b1;
    end else begin
        if (orig_d0 <= orig_d1) begin
            new_d0 = orig_d0;
            new_d1 = orig_d1;
            cost_per_digit = 2'd0;
            new_state_bit = (orig_d0 < orig_d1) ? 1'b1 : 1'b0;
        end else begin
            new_d0 = orig_d0;
            new_d1 = orig_d0;
            cost_per_digit = (orig_d1 != orig_d0) ? 2'd1 : 2'd0;
            new_state_bit = 1'b0; // Still equal
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= STATE_IDLE;
        done <= 1'b0;
        digit_idx <= 3'd0;
        state_vector <= 1'b0;
        total_cost <= 16'd0;
        temp_numbers <= 0;
        numbers_out <= 0;
    end else begin
        case (current_state)
            STATE_IDLE: begin
                done <= 1'b0;
                digit_idx <= 3'd0;
                state_vector <= 1'b0;
                total_cost <= 16'd0;
                temp_numbers <= 0;
                if (start) current_state <= STATE_COMPUTE;
            end

            STATE_COMPUTE: begin
                temp_numbers[0][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH] <= new_d0;
                temp_numbers[1][digit_idx*DIGIT_WIDTH +: DIGIT_WIDTH] <= new_d1;
                total_cost <= total_cost + cost_per_digit;
                state_vector <= new_state_bit;

                if (digit_idx == (M-1)) begin
                    current_state <= STATE_OUTPUT;
                end else begin
                    digit_idx <= digit_idx + 3'd1;
                end
            end

            STATE_OUTPUT: begin
                numbers_out <= temp_numbers;
                current_state <= STATE_DONE;
            end

            STATE_DONE: begin
                done <= 1'b1;
                if (!start) current_state <= STATE_IDLE;
            end

            default: current_state <= STATE_IDLE;
        endcase
    end
end

endmodule