module GridStampChecker(
    input clk,
    input rst_n,
    input start,
    input [1:0] target [0:7] [0:7],
    input [3:0] rows,
    input [3:0] cols,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [3:0] i_reg, j_reg;
    reg [1:0] current_color;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            current_color <= 2'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b1;  // Assume YES until proven otherwise
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        i_reg <= 4'd1;
                        j_reg <= 4'd1;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all 3x3 regions
                    if (i_reg >= rows - 2 || j_reg >= cols - 2) begin
                        state <= FINISH;
                    end else begin
                        // Extract current 3x3 region
                        reg [1:0] region [0:2] [0:2];
                        integer i, j;
                        
                        // Load the 3x3 region
                        for (i = 0; i < 3; i = i + 1) begin
                            for (j = 0; j < 3; j = j + 1) begin
                                region[i][j] <= target[i_reg + i - 1][j_reg + j - 1];
                            end
                        end
                        
                        // Check if all cells are white
                        reg all_white;
                        all_white = 1'b1;
                        for (i = 0; i < 3; i = i + 1) begin
                            for (j = 0; j < 3; j = j + 1) begin
                                if (region[i][j] != 2'd3) begin
                                    all_white = 1'b0;
                                end
                            end
                        end
                        
                        // Check if all cells are the same non-white color
                        reg all_same;
                        reg [1:0] first_color;
                        all_same = 1'b1;
                        first_color = region[0][0];
                        
                        if (first_color == 2'd3) begin
                            all_same = 1'b0;  // White doesn't count for non-white check
                        end else begin
                            for (i = 0; i < 3; i = i + 1) begin
                                for (j = 0; j < 3; j = j + 1) begin
                                    if (region[i][j] != first_color) begin
                                        all_same = 1'b0;
                                    end
                                end
                            end
                        end
                        
                        // If neither condition is met, result is NO
                        if (!all_white && !all_same) begin
                            result <= 1'b0;
                        end
                        
                        // Move to next position
                        j_reg <= j_reg + 4'd1;
                        if (j_reg >= cols - 2) begin
                            j_reg <= 4'd1;
                            i_reg <= i_reg + 4'd1;
                        end
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
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