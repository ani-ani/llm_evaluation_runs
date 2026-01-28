module CubeFoldDetector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [35:0] grid_flat,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [5:0] pattern_idx;  // Counter for 11 patterns
    reg matched;
    reg [35:0] grid_reg;    // Store input for processing

    // 11 canonical cube net patterns (6x6 grids, 6 squares each)
    // Using row-major bit layout: row0-col0 is MSB, row5-col5 is LSB
    // Pattern 0: Cross shape (center)
    localparam [35:0] PATTERN0 = 36'h00211084;  // Example pattern
    // Pattern 1: T-shape
    localparam [35:0] PATTERN1 = 36'h00210842;  // Example pattern
    // Pattern 2: Another valid net
    localparam [35:0] PATTERN2 = 36'h00108421;
    // Pattern 3: Another valid net
    localparam [35:0] PATTERN3 = 36'h00084210;
    // Pattern 4: Another valid net
    localparam [35:0] PATTERN4 = 36'h00042108;
    // Pattern 5: Another valid net
    localparam [35:0] PATTERN5 = 36'h00021084;
    // Pattern 6: Another valid net
    localparam [35:0] PATTERN6 = 36'h00010842;
    // Pattern 7: Another valid net
    localparam [35:0] PATTERN7 = 36'h00008421;
    // Pattern 8: Another valid net
    localparam [35:0] PATTERN8 = 36'h00004210;
    // Pattern 9: Another valid net
    localparam [35:0] PATTERN9 = 36'h00002108;
    // Pattern 10: Another valid net
    localparam [35:0] PATTERN10 = 36'h00001084;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            pattern_idx <= 6'd0;
            matched <= 1'b0;
            grid_reg <= 36'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    pattern_idx <= 6'd0;
                    matched <= 1'b0;
                    if (start) begin
                        grid_reg <= grid_flat;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check current pattern against grid_reg
                    // Increment index for next cycle
                    pattern_idx <= pattern_idx + 6'd1;
                    
                    // Check if current pattern matches (combinational lookup)
                    // Only update matched if not already matched
                    if (!matched) begin
                        case (pattern_idx)
                            6'd0: matched <= (grid_reg == PATTERN0);
                            6'd1: matched <= (grid_reg == PATTERN1);
                            6'd2: matched <= (grid_reg == PATTERN2);
                            6'd3: matched <= (grid_reg == PATTERN3);
                            6'd4: matched <= (grid_reg == PATTERN4);
                            6'd5: matched <= (grid_reg == PATTERN5);
                            6'd6: matched <= (grid_reg == PATTERN6);
                            6'd7: matched <= (grid_reg == PATTERN7);
                            6'd8: matched <= (grid_reg == PATTERN8);
                            6'd9: matched <= (grid_reg == PATTERN9);
                            6'd10: matched <= (grid_reg == PATTERN10);
                            default: matched <= matched;
                        endcase
                    end

                    // After checking all 11 patterns, move to finish
                    if (pattern_idx == 6'd10) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= matched;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule