module MonotonicChecker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg signed [7:0] stored_arr [0:7];
    reg [3:0] stored_len;
    reg [3:0] comp_idx;
    reg direction; // 1 = increasing, 0 = decreasing
    reg direction_valid;
    reg result_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;
    
    integer i;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Initialize all registers
            result <= 1'b0;
            done <= 1'b0;
            result_reg <= 1'b0;
            comp_idx <= 4'd0;
            direction <= 1'b0;
            direction_valid <= 1'b0;
            cycle_count <= 4'd0;
            stored_len <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                stored_arr[i] <= 8'sd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Capture inputs
                        stored_len <= len;
                        for (i = 0; i < 8; i = i + 1) begin
                            stored_arr[i] <= arr[i];
                        end
                        
                        // Pre-calculate result for edge cases
                        if (len <= 4'd1) begin
                            result_reg <= 1'b1;
                        end else begin
                            result_reg <= 1'b1; // Assume monotonic until proven otherwise
                        end
                        
                        comp_idx <= 4'd0;
                        direction_valid <= 1'b0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (comp_idx < stored_len - 4'd1) begin
                        // Compare current and next element
                        if (stored_arr[comp_idx] < stored_arr[comp_idx + 1]) begin
                            // Increasing
                            if (!direction_valid) begin
                                direction <= 1'b1; // Set as increasing
                                direction_valid <= 1'b1;
                            end else if (!direction) begin
                                // Was decreasing, now increasing - not monotonic
                                result_reg <= 1'b0;
                            end
                        end else if (stored_arr[comp_idx] > stored_arr[comp_idx + 1]) begin
                            // Decreasing
                            if (!direction_valid) begin
                                direction <= 1'b0; // Set as decreasing
                                direction_valid <= 1'b1;
                            end else if (direction) begin
                                // Was increasing, now decreasing - not monotonic
                                result_reg <= 1'b0;
                            end
                        end
                        // If equal, direction stays the same
                        
                        comp_idx <= comp_idx + 4'd1;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    result <= result_reg;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && rst_n) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // Complete when: 
                // 1. All comparisons done
                // 2. Result is already 0 (violated monotonic)
                // 3. Hit cycle limit (safety)
                if ((comp_idx >= stored_len - 4'd1) || 
                    (result_reg == 1'b0) || 
                    (cycle_count >= MAX_CYCLES)) begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule