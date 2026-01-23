module magic_checkerboard_2x2 (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_00, grid_01, grid_10, grid_11,
    output reg [7:0] result,
    output reg done
);
    // Internal registers for candidate values
    reg [3:0] v10, v01, v11; // Values for positions (1,0), (0,1), (1,1)
    reg [11:0] iteration_count; // 15*15*15 = 3375 < 2^12
    reg searching;
    
    // Wires to represent current cell values (fixed or variable)
    wire [3:0] c00 = grid_00;
    wire [3:0] c01 = (grid_01 == 4'd0) ? v01 : grid_01;
    wire [3:0] c10 = (grid_10 == 4'd0) ? v10 : grid_10;
    wire [3:0] c11 = (grid_11 == 4'd0) ? v11 : grid_11;
    
    // Constraints check
    // 1. All cells > 0 (inputs are 0-15, but 0 is only for empty, our vars start at 1)
    // 2. Row 0: c00 < c01
    // 3. Row 1: c10 < c11
    // 4. Col 0: c00 < c10
    // 5. Col 1: c01 < c11
    // 6. Diagonal Parity: c00[0] ^ c11[0] == 1
    wire valid;
    wire [7:0] current_sum;
    
    assign current_sum = c00 + c01 + c10 + c11;
    
    assign valid = (c00 > 0) && (c01 > 0) && (c10 > 0) && (c11 > 0) &&
                   (c00 < c01) && (c10 < c11) &&
                   (c00 < c10) && (c01 < c11) &&
                   (c00[0] ^ c11[0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'hFF; // -1
            done <= 0;
            searching <= 0;
            iteration_count <= 0;
            v10 <= 4'd1; v01 <= 4'd1; v11 <= 4'd1;
        end else begin
            if (start && !searching) begin
                // Initialize search
                searching <= 1;
                done <= 0;
                result <= 8'hFF; // Reset result to -1
                v10 <= 4'd1; v01 <= 4'd1; v11 <= 4'd1;
                iteration_count <= 0;
            end else if (searching) begin
                if (iteration_count < 12'd3375) begin
                    // Check current configuration
                    if (valid) begin
                        if (result == 8'hFF || current_sum < result) begin
                            result <= current_sum;
                        end
                    end
                    
                    // Increment counter logic (Manual carry propagation for 3 digits of base 15)
                    // v10 is digit 0 (LSB), v01 is digit 1, v11 is digit 2
                    if (v10 < 4'd15) begin
                        v10 <= v10 + 1;
                    end else begin
                        v10 <= 4'd1; // Reset digit 0
                        if (v01 < 4'd15) begin
                            v01 <= v01 + 1;
                        end else begin
                            v01 <= 4'd1; // Reset digit 1
                            if (v11 < 4'd15) begin
                                v11 <= v11 + 1;
                            end
                        end
                    end
                    iteration_count <= iteration_count + 1;
                end else begin
                    searching <= 0;
                    done <= 1;
                end
            end else begin
                done <= 0; // Ensure done pulses only once
            end
        end
    end
endmodule