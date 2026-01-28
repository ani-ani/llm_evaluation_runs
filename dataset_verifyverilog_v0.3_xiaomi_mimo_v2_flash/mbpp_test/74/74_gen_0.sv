module pattern_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Fixed-width color inputs (8 elements of 8 ASCII chars each)
    // Each color is represented as 64-bit packed ASCII (8 chars * 8 bits)
    input wire [63:0] colors_0,
    input wire [63:0] colors_1,
    input wire [63:0] colors_2,
    input wire [63:0] colors_3,
    input wire [63:0] colors_4,
    input wire [63:0] colors_5,
    input wire [63:0] colors_6,
    input wire [63:0] colors_7,
    
    // Pattern inputs (8 elements of 8-bit pattern codes)
    input wire [7:0] patterns_0,
    input wire [7:0] patterns_1,
    input wire [7:0] patterns_2,
    input wire [7:0] patterns_3,
    input wire [7:0] patterns_4,
    input wire [7:0] patterns_5,
    input wire [7:0] patterns_6,
    input wire [7:0] patterns_7,
    
    input wire [3:0] num_elements,  // Number of valid elements (1-8)
    
    output reg result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_LEN  = 3'd1;
    localparam [2:0] BUILD_MAP  = 3'd2;
    localparam [2:0] VERIFY     = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    
    reg [2:0] state, next_state;
    reg [3:0] idx;
    reg [7:0] current_pattern;
    reg [63:0] expected_color;
    reg pattern_found;
    reg [7:0] unique_patterns [0:7];
    reg [63:0] mapped_colors [0:7];
    reg [3:0] pattern_count;
    reg [3:0] verify_idx;
    reg color_mismatch;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    integer i;
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CHECK_LEN;
            CHECK_LEN: next_state = BUILD_MAP;
            BUILD_MAP: if (idx >= num_elements || color_mismatch) next_state = VERIFY;
            VERIFY: if (verify_idx >= pattern_count) next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // State register and combinational logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            idx <= 4'd0;
            pattern_count <= 4'd0;
            verify_idx <= 4'd0;
            color_mismatch <= 1'b0;
            cycle_count <= 8'd0;
            current_pattern <= 8'd0;
            expected_color <= 64'd0;
            pattern_found <= 1'b0;
            // Clear mappings
            for (i = 0; i < 8; i = i + 1) begin
                unique_patterns[i] <= 8'd0;
                mapped_colors[i] <= 64'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    idx <= 4'd0;
                    pattern_count <= 4'd0;
                    verify_idx <= 4'd0;
                    color_mismatch <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                CHECK_LEN: begin
                    // Verify num_elements is valid (1-8)
                    if (num_elements == 4'd0 || num_elements > 4'd8) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end
                end
                
                BUILD_MAP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (idx < num_elements && !color_mismatch && cycle_count < MAX_CYCLES) begin
                        // Get current pattern and color based on index
                        case (idx)
                            4'd0: begin current_pattern <= patterns_0; expected_color <= colors_0; end
                            4'd1: begin current_pattern <= patterns_1; expected_color <= colors_1; end
                            4'd2: begin current_pattern <= patterns_2; expected_color <= colors_2; end
                            4'd3: begin current_pattern <= patterns_3; expected_color <= colors_3; end
                            4'd4: begin current_pattern <= patterns_4; expected_color <= colors_4; end
                            4'd5: begin current_pattern <= patterns_5; expected_color <= colors_5; end
                            4'd6: begin current_pattern <= patterns_6; expected_color <= colors_6; end
                            4'd7: begin current_pattern <= patterns_7; expected_color <= colors_7; end
                            default: begin current_pattern <= 8'd0; expected_color <= 64'd0; end
                        endcase
                        
                        // Check if pattern exists in map
                        pattern_found <= 1'b0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (unique_patterns[i] == current_pattern) begin
                                pattern_found <= 1'b1;
                                // Verify color consistency
                                if (mapped_colors[i] != expected_color) begin
                                    color_mismatch <= 1'b1;
                                end
                            end
                        end
                        
                        // Add new pattern if not found and within bounds
                        if (!pattern_found && !color_mismatch && pattern_count < 8) begin
                            unique_patterns[pattern_count] <= current_pattern;
                            mapped_colors[pattern_count] <= expected_color;
                            pattern_count <= pattern_count + 4'd1;
                        end
                        
                        idx <= idx + 4'd1;
                    end
                end
                
                VERIFY: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (verify_idx < pattern_count && cycle_count < MAX_CYCLES) begin
                        // Check color consistency (already done during BUILD_MAP)
                        // Now verify all mapped colors are consistent
                        if (verify_idx == 0) begin
                            // First check: if we had any color mismatches
                            if (color_mismatch) begin
                                result <= 1'b0;
                            end else begin
                                // All colors match for each pattern
                                // Check that we have at least one pattern
                                if (pattern_count > 4'd0) begin
                                    result <= 1'b1;
                                end else begin
                                    result <= 1'b0;
                                end
                            end
                        end
                        verify_idx <= verify_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
            
            // Auto-clear done when returning to IDLE with start signal
            if (state == IDLE && start) begin
                done <= 1'b0;
            end
            
            // If exceeded max cycles, go to finish
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                result <= 1'b0;
                state <= FINISH;
            end
        end
    end

endmodule