module unique (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in [0:7],
    input [2:0] valid_count,
    output reg [7:0] result [0:7],
    output reg [2:0] unique_count,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam SORT = 3'b010;
    localparam DEDUP = 3'b011;
    localparam SHIFT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;
    
    // Internal buffers
    reg [7:0] buffer [0:7];
    reg [7:0] dedup_buffer [0:7];
    
    // Counters and indices
    reg [2:0] load_idx;
    reg [2:0] sort_i, sort_j;
    reg [2:0] dedup_idx;
    reg [2:0] shift_idx;
    reg [2:0] unique_cnt_reg;
    
    // Swap flag for bubble sort
    reg swap_needed;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            unique_count <= 3'b0;
            load_idx <= 3'b0;
            sort_i <= 3'b0;
            sort_j <= 3'b0;
            dedup_idx <= 3'b0;
            shift_idx <= 3'b0;
            unique_cnt_reg <= 3'b0;
            swap_needed <= 1'b0;
            // Reset result array (optional, but good practice)
            result[0] <= 8'b0; result[1] <= 8'b0; result[2] <= 8'b0; result[3] <= 8'b0;
            result[4] <= 8'b0; result[5] <= 8'b0; result[6] <= 8'b0; result[7] <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        load_idx <= 3'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load input data into buffer
                    if (load_idx < valid_count) begin
                        buffer[load_idx] <= data_in[load_idx];
                        load_idx <= load_idx + 1;
                        next_state <= LOAD;
                    end else begin
                        // Fill remaining with max value to avoid interfering with sorting
                        // Note: The requirement says valid_count is 1-8, so we handle exactly valid_count elements
                        // However, bubble sort needs to work on the whole array, so we need to handle 8 elements total.
                        // We will just sort the valid elements and keep the rest as is (or ignore them in logic).
                        // A cleaner approach is to pad with 8'hFF if less than 8 elements.
                        if (load_idx < 8) begin
                            buffer[load_idx] <= 8'hFF;
                            load_idx <= load_idx + 1;
                            next_state <= LOAD;
                        end else begin
                            sort_i <= 3'b0;
                            sort_j <= 3'b0;
                            next_state <= SORT;
                        end
                    end
                end
                
                SORT: begin
                    // Bubble sort (n-1 passes, here 8 elements -> 7 passes max, but we iterate full loop for simplicity)
                    // Logic: Iterate i from 0 to 6, j from 0 to 6-i (or just j < 7-i)
                    // We will use a simple counter structure: sort_i goes 0 to 6, sort_j goes 0 to 7
                    // Let's refine: sort_j goes 0 to 6, compare j and j+1
                    
                    if (sort_j < 7) begin
                        // Compare buffer[sort_j] and buffer[sort_j+1]
                        if (buffer[sort_j] > buffer[sort_j+1]) begin
                            // Swap
                            buffer[sort_j] <= buffer[sort_j+1];
                            buffer[sort_j+1] <= buffer[sort_j];
                        end
                        sort_j <= sort_j + 1;
                        next_state <= SORT;
                    end else begin
                        // One pass complete
                        sort_j <= 3'b0;
                        sort_i <= sort_i + 1;
                        if (sort_i < 6) begin // Need 7 passes for 8 elements (0..6 passes = 7 total)
                            next_state <= SORT;
                        end else begin
                            dedup_idx <= 3'b1; // Start checking from index 1
                            unique_cnt_reg <= 3'b1; // At least first element is unique (if valid_count >= 1)
                            // Initialize dedup buffer with first element
                            if (valid_count > 0) dedup_buffer[0] <= buffer[0];
                            next_state <= DEDUP;
                        end
                    end
                end
                
                DEDUP: begin
                    // Remove adjacent duplicates
                    // We iterate through the sorted buffer (only up to valid_count)
                    if (dedup_idx < valid_count) begin
                        if (buffer[dedup_idx] != buffer[dedup_idx - 1]) begin
                            dedup_buffer[unique_cnt_reg] <= buffer[dedup_idx];
                            unique_cnt_reg <= unique_cnt_reg + 1;
                        end
                        dedup_idx <= dedup_idx + 1;
                        next_state <= DEDUP;
                    end else begin
                        // DEDUP done
                        shift_idx <= 3'b0;
                        unique_count <= unique_cnt_reg;
                        next_state <= SHIFT;
                    end
                end
                
                SHIFT: begin
                    // Shift unique elements to beginning of result array
                    if (shift_idx < unique_cnt_reg) begin
                        result[shift_idx] <= dedup_buffer[shift_idx];
                        shift_idx <= shift_idx + 1;
                        next_state <= SHIFT;
                    end else begin
                        // Fill rest with 0 or keep as is (don't care, but let's zero out for cleanliness)
                        // The problem says "Remaining output positions contain previous values (don't care)"
                        // So we just finish.
                        done <= 1'b1;
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    // Wait for reset or new start
                    done <= 1'b1;
                    if (start) begin
                        // Restart logic
                        done <= 1'b0;
                        next_state <= LOAD;
                        load_idx <= 3'b0;
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule
