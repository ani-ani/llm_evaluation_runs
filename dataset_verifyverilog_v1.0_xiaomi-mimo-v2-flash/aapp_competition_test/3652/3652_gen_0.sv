module DeleteColumnsToSort (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [3:0] row0 [0:15],
    input wire [3:0] row1 [0:15],
    input wire [3:0] row2 [0:15],
    output reg [4:0] min_deletions,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Parameters
    localparam [4:0] MAX_N = 5'd16;
    localparam [16:0] MAX_MASK = 17'd65536; // 2^16
    
    // Registers for iteration
    reg [16:0] mask_counter;
    reg [4:0] current_popcount;
    reg [4:0] best_popcount;
    
    // Registers for counting values in rows
    reg [4:0] count0 [0:15]; // Count of values 1-16 in Row 0
    reg [4:0] count1 [0:15]; // Count of values 1-16 in Row 1
    reg [4:0] count2 [0:15]; // Count of values 1-16 in Row 2
    
    // Index for loops
    reg [4:0] i;
    reg [4:0] j;
    
    // Internal control signals
    reg processing_done;
    reg [4:0] n_limit;
    
    // FSM Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_deletions <= 5'd0;
            done <= 1'b0;
            mask_counter <= 17'd0;
            best_popcount <= 5'd0;
            current_popcount <= 5'd0;
            processing_done <= 1'b0;
            n_limit <= 5'd0;
            // Initialize count arrays
            for (i = 0; i < 5'd16; i = i + 1) begin
                count0[i] <= 5'd0;
                count1[i] <= 5'd0;
                count2[i] <= 5'd0;
            end
            i <= 5'd0;
            j <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        n_limit <= N;
                        best_popcount <= 5'd0;
                        mask_counter <= 17'd0;
                        processing_done <= 1'b0;
                    end
                end
                
                LOAD: begin
                    // Load data into count arrays for current mask
                    // We iterate through all columns (0 to N-1)
                    if (i < n_limit) begin
                        // Check if column 'i' is selected in mask
                        if (mask_counter[i]) begin
                            // Increment counts for value in row0[i]
                            // Values are 1-16, map to index 0-15
                            if (row0[i] != 4'd0) begin
                                count0[row0[i] - 4'd1] <= count0[row0[i] - 4'd1] + 5'd1;
                            end
                            if (row1[i] != 4'd0) begin
                                count1[row1[i] - 4'd1] <= count1[row1[i] - 4'd1] + 5'd1;
                            end
                            if (row2[i] != 4'd0) begin
                                count2[row2[i] - 4'd1] <= count2[row2[i] - 4'd1] + 5'd1;
                            end
                        end
                        i <= i + 5'd1;
                    end else begin
                        i <= 5'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Check if counts match for all values
                    // Logic: valid is true if count0[k] == count1[k] == count2[k] for all k
                    // Optimization: Check if count0[k] != count1[k] or count0[k] != count2[k]
                    
                    if (i < n_limit) begin
                        // Check if current value counts match
                        if (count0[i] != count1[i] || count0[i] != count2[i]) begin
                            // Mismatch found, this mask is invalid
                            // We can stop checking, but need to clean up state
                            // We will just go to next mask after clearing
                            processing_done <= 1'b1; // Flag to indicate skip update
                        end
                        i <= i + 5'd1;
                    end else begin
                        // Finished checking all values
                        if (!processing_done) begin
                            // If we get here, all counts matched
                            // Update best_popcount
                            if (current_popcount > best_popcount) begin
                                best_popcount <= current_popcount;
                            end
                        end
                        
                        // Prepare for next mask iteration
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Clean up for next mask
                    // Reset counts to zero
                    if (i < n_limit) begin
                        count0[i] <= 5'd0;
                        count1[i] <= 5'd0;
                        count2[i] <= 5'd0;
                        i <= i + 5'd1;
                    end else begin
                        // Check if finished all masks
                        if (mask_counter >= ((1 << n_limit) - 1)) begin
                            // Calculate result: N - best_popcount
                            min_deletions <= n_limit - best_popcount;
                            state <= DONE_STATE;
                        end else begin
                            // Next mask
                            mask_counter <= mask_counter + 17'd1;
                            // Recalculate popcount for new mask (using simple shift-add)
                            // We reuse i for popcount calculation loop
                            i <= 5'd0;
                            current_popcount <= 5'd0;
                            processing_done <= 1'b0;
                            // We need to jump back to LOAD, but LOAD expects i reset
                            // To avoid infinite loop or complex state, we use a sub-state or jump
                            // Let's use a small loop here for popcount before going to LOAD
                            state <= 3'd5; // Temporary state for popcount calc
                        end
                    end
                end
                
                3'd5: begin // POPCOUNT_STATE
                    if (i < n_limit) begin
                        if (mask_counter[i]) begin
                            current_popcount <= current_popcount + 5'd1;
                        end
                        i <= i + 5'd1;
                    end else begin
                        i <= 5'd0; // Reset i for LOAD phase
                        state <= LOAD;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule