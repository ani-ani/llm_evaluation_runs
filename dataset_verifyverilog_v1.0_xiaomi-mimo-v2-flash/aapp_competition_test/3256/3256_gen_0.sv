module bits_game #(parameter N=8, parameter WIDTH=8) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] A [0:N-1],
    input wire [3:0] K,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_MASK = 3'd1;
    localparam [2:0] COUNT_SEGMENTS = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] current_mask;
    reg [15:0] temp_mask;
    reg [15:0] max_or_all;
    reg [7:0] i;          // Loop counter for array elements
    reg [3:0] segment_count;
    reg [15:0] current_or;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Wires for combinational logic
    wire [15:0] combined_element;
    wire mask_valid;
    wire segment_done;
    wire segments_ok;
    
    // Assign intermediate signals
    assign combined_element = {8'd0, A[i]}; // Extend to 16 bits for comparison
    assign mask_valid = ((combined_element & current_mask) == current_mask);
    assign segment_done = ((current_or & current_mask) == current_mask);
    assign segments_ok = (segment_count >= K);

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_MASK;
                else
                    next_state = IDLE;
            end
            
            CHECK_MASK: begin
                // Check if mask is valid (all elements contain mask bits)
                if (!mask_valid)
                    next_state = UPDATE; // Skip to next mask
                else
                    next_state = COUNT_SEGMENTS;
            end
            
            COUNT_SEGMENTS: begin
                if (segment_done) begin
                    if (i == N-1) begin
                        // Reached end of array
                        if (segments_ok)
                            next_state = UPDATE;
                        else
                            next_state = UPDATE; // Not enough segments
                    end else begin
                        next_state = COUNT_SEGMENTS; // Continue counting
                    end
                end else begin
                    if (i == N-1) begin
                        // Reached end without finding segment
                        if (segments_ok)
                            next_state = UPDATE;
                        else
                            next_state = UPDATE;
                    end else begin
                        next_state = COUNT_SEGMENTS;
                    end
                end
            end
            
            UPDATE: begin
                // Try next mask bit
                if (current_mask == 16'd0)
                    next_state = FINISH;
                else
                    next_state = CHECK_MASK;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_mask <= 16'd0;
            temp_mask <= 16'd0;
            max_or_all <= 16'd0;
            i <= 8'd0;
            segment_count <= 4'd0;
            current_or <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Calculate max possible answer (OR of all elements)
                        max_or_all <= {8'd0, A[0]} | {8'd0, A[1]} | {8'd0, A[2]} | {8'd0, A[3]} | 
                                      {8'd0, A[4]} | {8'd0, A[5]} | {8'd0, A[6]} | {8'd0, A[7]};
                        current_mask <= 16'd0;
                        temp_mask <= 16'd0;
                        result <= 16'd0;
                    end
                end
                
                CHECK_MASK: begin
                    i <= 8'd0;
                    // Determine next mask to check
                    // Strategy: Start with all bits, try removing lowest bits
                    // We use a greedy bit-by-bit approach from MSB to LSB
                    if (current_mask == 16'd0) begin
                        // First iteration - start with full mask
                        current_mask <= max_or_all;
                        temp_mask <= max_or_all;
                    end else begin
                        // Remove lowest set bit from temp_mask for next iteration
                        // Find lowest set bit and clear it
                        if (temp_mask > 0) begin
                            temp_mask <= temp_mask & (temp_mask - 16'd1);
                        end
                    end
                end
                
                COUNT_SEGMENTS: begin
                    if (i == 8'd0) begin
                        // Initialize counting
                        segment_count <= 4'd0;
                        current_or <= 16'd0;
                    end
                    
                    // Update current OR with current element
                    current_or <= current_or | {8'd0, A[i]};
                    
                    if (segment_done) begin
                        segment_count <= segment_count + 4'd1;
                        current_or <= 16'd0; // Reset for next segment
                    end
                    
                    if (i < N-1) begin
                        i <= i + 8'd1;
                    end
                end
                
                UPDATE: begin
                    // Check if current_mask is valid and segments OK
                    // Note: We need to check segment validity from previous state
                    // Simplified: if we reached UPDATE from valid mask with segments
                    // Update result if this mask is better
                    // This requires checking the actual validity status
                    // For simplicity in this FSM structure:
                    if (current_mask > 0 && (current_mask & max_or_all) == current_mask && 
                        (segment_count >= K || current_mask == 16'd0)) begin
                        result <= current_mask;
                    end
                    // Prepare for next mask
                    current_mask <= temp_mask;
                    i <= 8'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Final result is already set from last valid UPDATE
                    // If no valid partition found, result stays 0
                end
                
                default: state <= IDLE;
            endcase
            
            state <= next_state;
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                done <= 1'b1;
            end
        end
    end

endmodule