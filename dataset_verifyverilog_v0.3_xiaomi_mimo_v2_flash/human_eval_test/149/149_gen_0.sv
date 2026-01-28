module sorted_list_sum (
    input clk,
    input rst_n,
    input start,
    input [7:0] strings_in [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FILTER    = 3'd1;
    localparam [2:0] SORT_PASS = 3'd2;
    localparam [2:0] DONE      = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] filter_idx;          // Index for input array (0-7)
    reg [2:0] buffer_idx;          // Index for temporary buffer (0-7)
    reg [2:0] sort_outer;          // Outer loop counter for bubble sort
    reg [2:0] sort_inner;          // Inner loop counter for bubble sort
    reg [2:0] valid_count;         // Number of valid (even length) strings
    reg [7:0] temp_buffer [0:7];   // Temporary storage for valid strings
    reg [7:0] temp_val_a;          // Temporary holding for swap comparison
    reg [7:0] temp_val_b;          // Temporary holding for swap comparison
    reg swap_needed;               // Flag to indicate if swap is needed
    reg result_copied;             // Flag to indicate result copy is done

    // Integer for loop initialization
    integer i;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            filter_idx <= 3'd0;
            buffer_idx <= 3'd0;
            valid_count <= 3'd0;
            sort_outer <= 3'd0;
            sort_inner <= 3'd0;
            swap_needed <= 1'b0;
            result_copied <= 1'b0;
            // Initialize result array to 0
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'h00;
                temp_buffer[i] <= 8'h00;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= FILTER;
                        filter_idx <= 3'd0;
                        buffer_idx <= 3'd0;
                        valid_count <= 3'd0;
                        result_copied <= 1'b0;
                    end
                end

                FILTER: begin
                    // Check LSB of current string
                    if (!strings_in[filter_idx][0]) begin // Even length (LSB=0)
                        temp_buffer[buffer_idx] <= strings_in[filter_idx];
                        buffer_idx <= buffer_idx + 3'd1;
                        valid_count <= valid_count + 3'd1;
                    end
                    
                    if (filter_idx == 3'd7) begin
                        state <= SORT_PASS;
                        sort_outer <= 3'd0;
                    end else begin
                        filter_idx <= filter_idx + 3'd1;
                    end
                end

                SORT_PASS: begin
                    // Simplified Bubble Sort Logic
                    // We perform 7 passes (0 to 6) on the valid elements only
                    // In each pass, we iterate through the buffer
                    
                    // Pass Logic:
                    // If sort_outer < 7 (i.e., valid_count - 1)
                    // Inner loop runs from 0 to valid_count - sort_outer - 2
                    
                    // Logic implemented via state updates
                    if (sort_outer < 3'd7 && valid_count > 3'd1) begin
                        if (sort_inner < valid_count - sort_outer - 3'd1) begin
                            // Comparison Step
                            if (temp_buffer[sort_inner] > temp_buffer[sort_inner + 3'd1]) begin
                                // Swap needed
                                temp_val_a <= temp_buffer[sort_inner];
                                temp_val_b <= temp_buffer[sort_inner + 3'd1];
                                swap_needed <= 1'b1;
                            end else begin
                                swap_needed <= 1'b0;
                            end
                            sort_inner <= sort_inner + 3'd1;
                        end else begin
                            // Reset inner for next outer loop or finish
                            sort_inner <= 3'd0;
                            sort_outer <= sort_outer + 3'd1;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Write sorted values to result array
                    if (!result_copied) begin
                        // Copy valid elements to result array (0 to valid_count-1)
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < valid_count)
                                result[i] <= temp_buffer[i];
                            else
                                result[i] <= 8'h00;
                        end
                        result_copied <= 1'b1;
                        done <= 1'b1;
                    end else begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
            
            // Handle Swap Logic (combinatorial update of temp_buffer)
            // This happens in parallel with the state updates
            if (state == SORT_PASS && swap_needed && sort_inner > 3'd0) begin
                temp_buffer[sort_inner - 3'd1] <= temp_val_b;
                temp_buffer[sort_inner] <= temp_val_a;
                swap_needed <= 1'b0; // Clear flag after use
            end
        end
    end

endmodule