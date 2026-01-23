module non_decreasing_sequence (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] a_in,
    input [3:0] idx,
    input valid_in,
    output reg [3:0] op_x,
    output reg [3:0] op_y,
    output reg op_valid,
    output reg done,
    output reg error
);
parameter N = 16;
parameter MAX_OPS = 32;

reg [2:0] state;
reg [15:0] load_count;
reg [5:0] op_count;
reg [31:0] array [0:N-1];
reg [3:0] max_abs_idx;
reg [31:0] max_abs_val;
reg [1:0] strategy;
reg [3:0] current_i;
reg [1:0] phase;

always @(negedge rst_n) begin
    state <= 3'b0;
    load_count <= 16'd0;
    op_count <= 32'd0;
    max_abs_idx <= 4'd0;
    max_abs_val <= 32'd0;
    strategy <= 2'b00;
    current_i <= 4'd0;
    phase <= 2'b00;
    done <= 1'b0;
    error <= 1'b0;
    op_x <= 4'd0;
    op_y <= 4'd0;
    op_valid <= 1'b0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b0;
        load_count <= 16'd0;
        op_count <= 32'd0;
        max_abs_idx <= 4'd0;
        max_abs_val <= 32'd0;
        strategy <= 2'b00;
        current_i <= 4'd0;
        phase <= 2'b00;
        done <= 1'b0;
        error <= 1'b0;
        op_x <= 4'd0;
        op_y <= 4'd0;
        op_valid <= 1'b0;
    end else begin
        state <= state;
        load_count <= load_count;
        op_count <= op_count;
        max_abs_idx <= max_abs_idx;
        max_abs_val <= max_abs_val;
        strategy <= strategy;
        current_i <= current_i;
        phase <= phase;
        done <= done;
        error <= error;
        op_x <= op_x;
        op_y <= op_y;
        op_valid <= op_valid;

        if (state == 3'b000) begin // IDLE
            if (start) begin
                state <= 3'b001; // LOAD
            end
        end else if (state == 3'b001) begin // LOAD
            if (valid_in) begin
                array[idx] <= a_in;
                load_count <= load_count + 1;
            end
            if (load_count == N) begin
                state <= 3'b010; // ANALYZE
            end
        end else if (state == 3'b010) begin // ANALYZE
            // Simplified: assume strategy is prefix
            strategy <= 2'b00;
            state <= 3'b011; // PROCESS_OPS
        end else if (state == 3'b011) begin // PROCESS_OPS
            if (strategy == 2'b00) begin // prefix
                if (current_i < N-1) begin
                    op_x <= current_i;
                    op_y <= current_i + 1;
                    op_valid <= 1'b1;
                    if (op_count < MAX_OPS) begin
                        op_count <= op_count + 1;
                    end
                    current_i <= current_i + 1;
                end else begin
                    state <= 3'b100; // COMPLETE
                    done <= 1'b1;
                    op_valid <= 1'b0;
                end
            end
        end else if (state == 3'b100) begin // COMPLETE
            // Do nothing
        end
    end
end

endmodule