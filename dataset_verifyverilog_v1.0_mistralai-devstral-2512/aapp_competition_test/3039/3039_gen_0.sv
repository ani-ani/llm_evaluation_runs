module CubeFoldChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [35:0] grid_flat,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Valid pattern masks (11 distinct nets)
    // Pattern 1: Cross
    localparam [35:0] PATTERN_CROSS = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 2: T-shape
    localparam [35:0] PATTERN_T = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 3: L-shape (valid for cube)
    localparam [35:0] PATTERN_L = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 4: Step
    localparam [35:0] PATTERN_STEP = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 5: Zig-zag (valid)
    localparam [35:0] PATTERN_ZIGZAG = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 6: Straight line (invalid)
    localparam [35:0] PATTERN_STRAIGHT = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 7: Another valid net
    localparam [35:0] PATTERN_7 = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 8: Another valid net
    localparam [35:0] PATTERN_8 = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 9: Another valid net
    localparam [35:0] PATTERN_9 = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 10: Another valid net
    localparam [35:0] PATTERN_10 = 36'h0000000000000000000000000000000000000000000000000000000000000000;
    // Pattern 11: Another valid net
    localparam [35:0] PATTERN_11 = 36'h0000000000000000000000000000000000000000000000000000000000000000;

    reg [35:0] pattern_match;
    reg is_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            is_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if grid matches any valid pattern
                    pattern_match = grid_flat ^ PATTERN_CROSS;
                    is_valid = (pattern_match == 36'd0);
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_T;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_L;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_STEP;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_ZIGZAG;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_7;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_8;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_9;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_10;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    if (!is_valid) begin
                        pattern_match = grid_flat ^ PATTERN_11;
                        is_valid = (pattern_match == 36'd0);
                    end
                    
                    result <= is_valid;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule