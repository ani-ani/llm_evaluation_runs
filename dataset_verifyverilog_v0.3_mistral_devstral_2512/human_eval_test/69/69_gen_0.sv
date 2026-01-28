module search_max_valid(
    input clk,
    input rst_n,
    input start,
    input [3:0] data_in,
    input [3:0] index,
    input valid_in,
    input done_in,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] LOAD   = 2'd1;
    localparam [1:0] CHECK  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Frequency array for values 0-15 (4-bit counters)
    reg [3:0] freq [0:15];
    integer i;

    // Current value being checked (15 down to 1)
    reg [3:0] current_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize frequency array
            for (i = 0; i < 16; i = i + 1) begin
                freq[i] <= 4'd0;
            end
            current_val <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    next_state = LOAD;
                    // Reset frequency array on start
                    for (i = 0; i < 16; i = i + 1) begin
                        freq[i] = 4'd0;
                    end
                end
            end

            LOAD: begin
                if (valid_in && data_in != 4'd0) begin
                    // Increment frequency for non-zero values
                    freq[data_in] = freq[data_in] + 4'd1;
                end
                if (done_in) begin
                    next_state = CHECK;
                    current_val = 4'd15;  // Start checking from 15
                end
            end

            CHECK: begin
                cycle_count = cycle_count + 8'd1;
                if (current_val >= 4'd1 && freq[current_val] >= current_val) begin
                    // Found valid result
                    result = {4'd0, current_val};
                    next_state = DONE_STATE;
                end else if (current_val == 4'd1) begin
                    // Checked all values, no match found
                    result = 8'hFF;  // -1 in 8-bit signed
                    next_state = DONE_STATE;
                end else begin
                    // Continue checking next lower value
                    current_val = current_val - 4'd1;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule