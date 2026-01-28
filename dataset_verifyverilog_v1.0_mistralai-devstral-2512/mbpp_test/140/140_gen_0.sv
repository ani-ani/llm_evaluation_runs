module flatten_unique(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr [0:7][0:7],
    input wire [3:0] len [0:7],
    output reg signed [15:0] result [0:63],
    output reg [5:0] valid_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Counters and indices
    reg [2:0] i_reg, i_next;          // Outer list index (0-7)
    reg [2:0] j_reg, j_next;          // Inner list index (0-7)
    reg [5:0] k_reg, k_next;          // Output buffer index (0-63)
    reg [5:0] count_reg, count_next;  // Current valid count
    
    // Current value being processed
    reg signed [15:0] current_val;
    
    // Lookup state
    reg [5:0] lookup_idx;             // Index for sequential lookup
    reg found;                        // Flag if value found in output
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            k_reg <= 6'd0;
            count_reg <= 6'd0;
            current_val <= 16'd0;
            lookup_idx <= 6'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid_count <= 6'd0;
            
            // Initialize result array
            integer idx;
            for (idx = 0; idx < 64; idx = idx + 1) begin
                result[idx] <= 16'd0;
            end
        end else begin
            state <= next_state;
            i_reg <= i_next;
            j_reg <= j_next;
            k_reg <= k_next;
            count_reg <= count_next;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        i_next <= 3'd0;
                        j_next <= 3'd0;
                        count_next <= 6'd0;
                    end else begin
                        next_state <= IDLE;
                        i_next <= i_reg;
                        j_next <= j_reg;
                        count_next <= count_reg;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all elements
                    if (i_reg == 3'd7 && j_reg >= len[7]) begin
                        next_state <= FINISH;
                        i_next <= i_reg;
                        j_next <= j_reg;
                        count_next <= count_reg;
                    end else begin
                        // Get current value
                        if (j_reg < len[i_reg]) begin
                            current_val <= arr[i_reg][j_reg];
                            next_state <= CHECK;
                            lookup_idx <= 6'd0;
                            found <= 1'b0;
                            i_next <= i_reg;
                            j_next <= j_reg;
                            count_next <= count_reg;
                        end else begin
                            // Move to next inner list
                            i_next <= i_reg + 3'd1;
                            j_next <= 3'd0;
                            count_next <= count_reg;
                            next_state <= PROCESS;
                        end
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Sequential lookup through output buffer
                    if (lookup_idx < count_reg) begin
                        if (result[lookup_idx] == current_val) begin
                            found <= 1'b1;
                        end
                        lookup_idx <= lookup_idx + 6'd1;
                        next_state <= CHECK;
                        i_next <= i_reg;
                        j_next <= j_reg;
                        count_next <= count_reg;
                    end else begin
                        // Lookup complete
                        if (!found && count_reg < 6'd64) begin
                            // Add to output buffer
                            result[count_reg] <= current_val;
                            count_next <= count_reg + 6'd1;
                        else begin
                            count_next <= count_reg;
                        end
                        
                        // Move to next element
                        if (j_reg < 7'd7) begin
                            j_next <= j_reg + 3'd1;
                        end else begin
                            j_next <= 3'd0;
                            i_next <= i_reg + 3'd1;
                        end
                        
                        next_state <= PROCESS;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid_count <= count_reg;
                    next_state <= IDLE;
                    i_next <= 3'd0;
                    j_next <= 3'd0;
                    count_next <= 6'd0;
                end
                
                default: begin
                    next_state <= IDLE;
                    i_next <= 3'd0;
                    j_next <= 3'd0;
                    count_next <= 6'd0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                i_next <= 3'd0;
                j_next <= 3'd0;
                count_next <= 6'd0;
            end
        end
    end

endmodule