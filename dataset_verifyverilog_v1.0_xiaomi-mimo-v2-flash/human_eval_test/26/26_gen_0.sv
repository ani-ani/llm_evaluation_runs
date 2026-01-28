module remove_duplicates (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result [0:15],
    output reg [3:0] out_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers and variables
    reg [1:0] state;
    reg [3:0] i;          // Input index
    reg [3:0] j;          // Duplicate check index
    reg [3:0] out_idx;    // Output position index
    reg is_duplicate;     // Flag for duplicate detection
    reg [7:0] current_val; // Current value being checked
    reg [3:0] cycle_count; // Cycle counter for safety
    localparam [3:0] MAX_CYCLES = 4'd15; // 16 elements max

    // Initialize result array with zeros
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_len <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            out_idx <= 4'd0;
            is_duplicate <= 1'b0;
            current_val <= 8'd0;
            cycle_count <= 4'd0;
            // Initialize all result elements to 0
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
            result[8] <= 8'd0;
            result[9] <= 8'd0;
            result[10] <= 8'd0;
            result[11] <= 8'd0;
            result[12] <= 8'd0;
            result[13] <= 8'd0;
            result[14] <= 8'd0;
            result[15] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= PROCESSING;
                        i <= 4'd0;
                        out_idx <= 4'd0;
                        out_len <= 4'd0;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if we've processed all elements or reached max cycles
                    if (i >= len || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        // Get current value
                        current_val <= arr[i];
                        j <= 4'd0;
                        is_duplicate <= 1'b0;
                        
                        // Check for duplicates in previous elements
                        // We need to handle this carefully - we'll use a multi-cycle approach
                        if (j < i) begin
                            // Compare with each previous element
                            if (arr[j] == current_val) begin
                                is_duplicate <= 1'b1;
                            end
                            // Increment j for next iteration
                            j <= j + 4'd1;
                        end else if (j >= i) begin
                            // Finished checking all previous elements
                            if (!is_duplicate) begin
                                // Add to result
                                result[out_idx] <= current_val;
                                out_idx <= out_idx + 4'd1;
                                out_len <= out_len + 4'd1;
                            end
                            // Move to next input element
                            i <= i + 4'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule