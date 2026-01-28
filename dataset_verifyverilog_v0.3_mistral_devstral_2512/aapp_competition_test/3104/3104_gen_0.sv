module equation_solver(
    input clk,
    input rst_n,
    input start,
    input [3:0] digits [0:7],
    input [3:0] length,
    input [7:0] target,
    output reg done,
    output reg [7:0] split,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;

    reg [2:0] state;
    reg [7:0] split_reg;
    reg [10:0] pattern_counter;
    reg [7:0] current_split;
    reg [15:0] current_sum;
    reg [3:0] digit_index;
    reg [3:0] current_number;
    reg [3:0] num_digits;
    reg [3:0] split_index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            split <= 8'd0;
            valid <= 1'b0;
            split_reg <= 8'd0;
            pattern_counter <= 11'd0;
            current_split <= 8'd0;
            current_sum <= 16'd0;
            digit_index <= 4'd0;
            current_number <= 4'd0;
            num_digits <= 4'd0;
            split_index <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    split <= 8'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                        pattern_counter <= 11'd0;
                        current_split <= 8'd0;
                        current_sum <= 16'd0;
                        digit_index <= 4'd0;
                        current_number <= 4'd0;
                        num_digits <= 4'd0;
                        split_index <= 4'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Generate next split pattern
                    if (digit_index == 4'd0) begin
                        // Start new pattern
                        current_split <= pattern_counter[7:0];
                        pattern_counter <= pattern_counter + 11'd1;
                        current_sum <= 16'd0;
                        current_number <= 4'd0;
                        num_digits <= 4'd0;
                        split_index <= 4'd0;
                    end

                    // Process current digit
                    if (digit_index < length) begin
                        current_number <= {current_number[2:0], digits[digit_index]};
                        num_digits <= num_digits + 4'd1;
                        
                        // Check if we need to add current number to sum
                        if (current_split[digit_index] || (digit_index == length - 4'd1)) begin
                            current_sum <= current_sum + current_number;
                            current_number <= 4'd0;
                        end
                        
                        digit_index <= digit_index + 4'd1;
                    end

                    // Check if we've processed all digits
                    if (digit_index == length) begin
                        if (current_sum == target) begin
                            split_reg <= current_split;
                            state <= DONE_STATE;
                        end else if (pattern_counter == 11'd(1 << (length - 4'd1))) begin
                            // All patterns tried, no solution (shouldn't happen per problem statement)
                            split_reg <= 8'd0;
                            state <= DONE_STATE;
                        end else begin
                            digit_index <= 4'd0;
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        split_reg <= 8'd0;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    split <= split_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule