module remove_consecutive_duplicates(
    input clk,
    input rst_n,
    input start,
    input [4:0] input_length,
    input [7:0] input_data [15:0],
    output reg [4:0] output_length,
    output reg [7:0] output_data [15:0],
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [4:0] idx_in;   // Index for reading input array (0 to 15)
    reg [4:0] idx_out;  // Index for writing output array (0 to 15)
    reg [7:0] prev_val; // Store the previous value for comparison
    reg is_first;       // Flag to indicate the first element

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            output_length <= 5'b0;
            done <= 1'b0;
            idx_in <= 5'b0;
            idx_out <= 5'b0;
            prev_val <= 8'b0;
            is_first <= 1'b1;
            // Explicitly reset output data array to avoid undefined states
            for (i = 0; i < 16; i = i + 1) begin
                output_data[i] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        idx_in <= 5'b0;
                        idx_out <= 5'b0;
                        output_length <= 5'b0;
                        is_first <= 1'b1;
                    end
                end

                PROCESSING: begin
                    if (idx_in < input_length) begin
                        // Process current element
                        if (is_first) begin
                            // Always take the first element
                            output_data[idx_out] <= input_data[idx_in];
                            idx_out <= idx_out + 1'b1;
                            output_length <= output_length + 1'b1;
                            prev_val <= input_data[idx_in];
                            is_first <= 1'b0;
                        end else begin
                            // Compare with previous
                            if (input_data[idx_in] != prev_val) begin
                                output_data[idx_out] <= input_data[idx_in];
                                idx_out <= idx_out + 1'b1;
                                output_length <= output_length + 1'b1;
                                prev_val <= input_data[idx_in];
                            end
                        end
                        idx_in <= idx_in + 1'b1;
                    end else begin
                        // Processing complete
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Stay in DONE state until reset or new start (optional behavior implied by "stays high until reset")
                    // If we want to allow restarting, we would check !start first, but requirements say stays high.
                    // Usually done stays high, we wait for reset.
                end
            endcase
        end
    end

endmodule
