module max_xor_subset(input clk, input rst_n, input start, input [2:0] num_count, input [31:0] data_in, input data_valid, output reg [31:0] result, output reg done, output reg busy);

// Internal registers
reg [1:2] state, next_state;
localparam IDLE = 2'd0, COLLECT = 2'd1, BUILD_BASIS = 2'd2, MAXIMIZE = 2'd3, DONE = 2'd4;
reg [2:0] count_collected, next_count_collected;
reg [31:0] input_nums [8], next_input_nums [8];
reg [2:0] input_count, next_input_count;
reg [31:0] basis [32], next_basis [32];
reg [31:0] current_num, next_current_num;
reg [2:0] num_idx, next_num_idx;
reg [5:0] bit_idx, next_bit_idx;
reg [31:0] max_result, next_max_result;
reg [5:0] max_bit_idx, next_max_bit_idx;
reg busy, next_busy;
reg done, next_done;

// Default assignments
always @(*) begin
    next_state <= state;
    next_count_collected <= count_collected;
    next_input_count <= input_count;
    next_basis <= basis;
    next_current_num <= current_num;
    next_num_idx <= num_idx;
    next_bit_idx <= bit_idx;
    next_max_result <= max_result;
    next_max_bit_idx <= max_bit_idx;
    next_busy <= busy;
    next_done <= done;
    next_input_nums <= input_nums;
end

// Clock and reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        count_collected <= 0;
        input_count <= 0;
        input_nums <= 0;
        basis <= 0;
        current_num <= 0;
        num_idx <= 0;
        bit_idx <= 0;
        max_result <= 0;
        max_bit_idx <= 31;
        busy <= 0;
        done <= 0;
    end else begin
        state <= next_state;
        count_collected <= next_count_collected;
        input_count <= next_input_count;
        input_nums <= next_input_nums;
        basis <= next_basis;
        current_num <= next_current_num;
        num_idx <= next_num_idx;
        bit_idx <= next_bit_idx;
        max_result <= next_max_result;
        max_bit_idx <= next_max_bit_idx;
        busy <= next_busy;
        done <= next_done;
    end
end

// Combinational logic
always @(*) begin
    // IDLE state
    if (state == IDLE) begin
        if (!rst_n) begin
            // Reset handling
        end else begin
            if (start == 1'b1) begin
                next_state <= COLLECT;
                next_input_count <= num_count;
                next_count_collected <= 0;
                next_busy <= 1'b1;
            end
        end
    end
    // COLLECT state
    else if (state == COLLECT) begin
        if (!rst_n) begin
            // Reset handling
        end else begin
            if (data_valid && count_collected < input_count) begin
                next_input_nums[count_collected] <= data_in;
                next_count_collected <= count_collected + 1;
            end
            if (count_collected == input_count) begin
                next_state <= BUILD_BASIS;
                next_basis <= 0;
                next_current_num <= input_nums[0];
                next_num_idx <= 0;
                next_bit_idx <= 31;
            end
        end
    end
    // BUILD_BASIS state
    else if (state == BUILD_BASIS) begin
        if (!rst_n) begin
            // Reset handling
        end else begin
            if (num_idx < input_count) begin
                if (bit_idx == 31) begin
                    next_current_num <= input_nums[num_idx];
                end
                if (bit_idx >= 0) begin
                    if (current_num & (1 << bit_idx)) begin
                        if (basis[bit_idx] == 0) begin
                            next_basis[bit_idx] <= current_num;
                            next_num_idx <= num_idx + 1;
                            next_bit_idx <= 31;
                            if (next_num_idx >= input_count) begin
                                next_state <= MAXIMIZE;
                            end
                        end else begin
                            next_current_num <= current_num ^ basis[bit_idx];
                        end
                    end
                    next_bit_idx <= bit_idx - 1;
                end else begin
                    next_num_idx <= num_idx + 1;
                    if (next_num_idx < input_count) begin
                        next_current_num <= input_nums[next_num_idx];
                        next_bit_idx <= 31;
                    end else begin
                        next_state <= MAXIMIZE;
                    end
                end
            end
        end
    end
    // MAXIMIZE state
    else if (state == MAXIMIZE) begin
        if (!rst_n) begin
            // Reset handling
        end else begin
            if (max_bit_idx >= 0) begin
                if (basis[max_bit_idx] != 0) begin
                    if ((max_result ^ basis[max_bit_idx]) > max_result) begin
                        next_max_result <= max_result ^ basis[max_bit_idx];
                    end
                end
                next_max_bit_idx <= max_bit_idx - 1;
            end else begin
                next_state <= DONE;
            end
        end
    end
    // DONE state
    else if (state == DONE) begin
        if (!rst_n) begin
            // Reset handling
        end else begin
            next_done <= 1'b1;
            next_busy <= 1'b0;
        end
    end
end

// Output assignments
assign busy = busy;
assign done = done;
assign result = (state == DONE) ? max_result : 32'd0;

endmodule