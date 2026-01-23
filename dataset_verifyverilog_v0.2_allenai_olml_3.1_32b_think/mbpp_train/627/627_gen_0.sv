module find_first_missing(
    input clk,
    input rst_n,
    input start,
    input [2:0] array_size,
    input [3:0] array_data [0:7],
    output reg [3:0] missing_number,
    output reg done
);

// Internal registers
reg [2:0] low;
reg [2:0] high;
reg [2:0] mid;
reg [2:0] iteration_count;
reg [2:0] captured_array_size;
reg [3:0] captured_array_data [0:7];
reg [3:0] missing_number;
reg done;
reg [1:0] state;

// State definitions
parameter IDLE = 2'd0;
parameter SEARCH = 2'd1;
parameter DONE = 2'd2;

always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        low <= 3'b0;
        high <= 3'b0;
        mid <= 3'b0;
        iteration_count <= 3'b0;
        captured_array_size <= 3'b0;
        captured_array_data <= {8{4'b0}}; // Initialize all elements to 0
        missing_number <= 4'b0;
        done <= 1'b0;
        state <= IDLE;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                // Capture input values
                captured_array_size <= array_size;
                captured_array_data <= array_data;
                // Check if array is empty
                if (array_size == 4'd0) begin
                    missing_number <= 4'd0;
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    // Initialize search parameters and move to SEARCH
                    low <= 3'b0;
                    high <= array_size - 1; // Use current input array_size
                    iteration_count <= 3'b0;
                    state <= SEARCH;
                end
            end
        end else if (state == SEARCH) begin
            if (low <= high) and (iteration_count < 4) begin
                // Perform binary search step
                mid = (low + high) >> 1;
                if (captured_array_data[mid] == mid) begin
                    low <= mid + 1;
                end else begin
                    high <= mid - 1;
                end
                iteration_count <= iteration_count + 1;
            end else begin
                // Exit to DONE and output result
                missing_number <= low;
                done <= 1'b1;
                state <= DONE;
            end
        end else if (state == DONE) begin
            // Remain in DONE state
        end
    end
end
endmodule