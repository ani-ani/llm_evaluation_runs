module arcade_expected(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] v [0:9],
    input wire [15:0] p0 [0:9],
    input wire [15:0] p1 [0:9],
    input wire [15:0] p2 [0:9],
    input wire [15:0] p3 [0:9],
    input wire [15:0] p4 [0:9],
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Matrix storage (10x11)
    reg signed [31:0] matrix [0:9][0:10];
    reg [3:0] row, col, pivot_row;
    reg signed [31:0] temp, mult_temp, div_temp;
    reg [31:0] abs_temp, max_abs;
    integer i, j, k;

    // Initialize matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            row <= 4'd0;
            col <= 4'd0;
            pivot_row <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Initialize matrix
                    for (i = 0; i < 10; i = i + 1) begin
                        for (j = 0; j < 10; j = j + 1) begin
                            matrix[i][j] <= 32'd0;
                        end
                        matrix[i][i] <= 32'd1 << 16;  // Diagonal = 1.0 in Q16.16
                    end
                    
                    // Set up equations based on neighbor mapping
                    // Hole 0
                    matrix[0][0] <= (32'd1 << 16) - (p4[0] << 16) - (p2[0] << 16) - (p3[0] << 16);
                    matrix[0][1] <= - (p2[0] << 16);
                    matrix[0][2] <= - (p3[0] << 16);
                    matrix[0][10] <= v[0] << 16;
                    
                    // Hole 1
                    matrix[1][0] <= - (p0[1] << 16);
                    matrix[1][1] <= (32'd1 << 16) - (p4[1] << 16) - (p2[1] << 16) - (p3[1] << 16);
                    matrix[1][3] <= - (p2[1] << 16);
                    matrix[1][4] <= - (p3[1] << 16);
                    matrix[1][10] <= v[1] << 16;
                    
                    // Hole 2
                    matrix[2][0] <= - (p0[2] << 16);
                    matrix[2][2] <= (32'd1 << 16) - (p4[2] << 16) - (p2[2] << 16) - (p3[2] << 16);
                    matrix[2][4] <= - (p2[2] << 16);
                    matrix[2][5] <= - (p3[2] << 16);
                    matrix[2][10] <= v[2] << 16;
                    
                    // Hole 3
                    matrix[3][1] <= - (p0[3] << 16);
                    matrix[3][3] <= (32'd1 << 16) - (p4[3] << 16) - (p2[3] << 16) - (p3[3] << 16);
                    matrix[3][4] <= - (p1[3] << 16);
                    matrix[3][6] <= - (p2[3] << 16);
                    matrix[3][7] <= - (p3[3] << 16);
                    matrix[3][10] <= v[3] << 16;
                    
                    // Hole 4
                    matrix[4][2] <= - (p0[4] << 16);
                    matrix[4][4] <= (32'd1 << 16) - (p4[4] << 16) - (p2[4] << 16) - (p3[4] << 16);
                    matrix[4][5] <= - (p1[4] << 16);
                    matrix[4][7] <= - (p2[4] << 16);
                    matrix[4][8] <= - (p3[4] << 16);
                    matrix[4][10] <= v[4] << 16;
                    
                    // Hole 5
                    matrix[5][5] <= (32'd1 << 16) - (p4[5] << 16) - (p2[5] << 16) - (p3[5] << 16);
                    matrix[5][8] <= - (p2[5] << 16);
                    matrix[5][9] <= - (p3[5] << 16);
                    matrix[5][10] <= v[5] << 16;
                    
                    // Hole 6
                    matrix[6][3] <= - (p0[6] << 16);
                    matrix[6][6] <= (32'd1 << 16) - (p4[6] << 16) - (p2[6] << 16) - (p3[6] << 16);
                    matrix[6][7] <= - (p1[6] << 16);
                    matrix[6][10] <= v[6] << 16;
                    
                    // Hole 7
                    matrix[7][4] <= - (p0[7] << 16);
                    matrix[7][7] <= (32'd1 << 16) - (p4[7] << 16) - (p2[7] << 16) - (p3[7] << 16);
                    matrix[7][8] <= - (p1[7] << 16);
                    matrix[7][10] <= v[7] << 16;
                    
                    // Hole 8
                    matrix[8][5] <= - (p0[8] << 16);
                    matrix[8][8] <= (32'd1 << 16) - (p4[8] << 16) - (p2[8] << 16) - (p3[8] << 16);
                    matrix[8][9] <= - (p1[8] << 16);
                    matrix[8][10] <= v[8] << 16;
                    
                    // Hole 9
                    matrix[9][9] <= (32'd1 << 16) - (p4[9] << 16);
                    matrix[9][10] <= v[9] << 16;
                    
                    next_state <= COMPUTE;
                    row <= 4'd0;
                    col <= 4'd0;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (row < 10 && col < 10) begin
                        // Partial pivoting
                        max_abs <= 32'd0;
                        pivot_row <= row;
                        for (i = row; i < 10; i = i + 1) begin
                            abs_temp <= matrix[i][col] < 32'd0 ? -matrix[i][col] : matrix[i][col];
                            if (abs_temp > max_abs) begin
                                max_abs <= abs_temp;
                                pivot_row <= i;
                            end
                        end
                        
                        // Swap rows
                        if (pivot_row != row) begin
                            for (j = col; j < 11; j = j + 1) begin
                                temp <= matrix[row][j];
                                matrix[row][j] <= matrix[pivot_row][j];
                                matrix[pivot_row][j] <= temp;
                            end
                        end
                        
                        // Normalize pivot row
                        if (matrix[row][col] != 32'd0) begin
                            for (j = col + 1; j < 11; j = j + 1) begin
                                // Fixed-point division: matrix[row][j] / matrix[row][col]
                                div_temp <= {matrix[row][j], 16'd0};
                                matrix[row][j] <= div_temp / matrix[row][col];
                            end
                            matrix[row][col] <= 32'd1 << 16;
                        end
                        
                        // Eliminate column
                        for (i = 0; i < 10; i = i + 1) begin
                            if (i != row && matrix[i][col] != 32'd0) begin
                                for (j = col + 1; j < 11; j = j + 1) begin
                                    // Fixed-point multiplication: matrix[i][col] * matrix[row][j]
                                    mult_temp <= matrix[i][col] * matrix[row][j];
                                    matrix[i][j] <= matrix[i][j] - (mult_temp >> 16);
                                end
                                matrix[i][col] <= 32'd0;
                            end
                        end
                        
                        // Move to next column
                        col <= col + 4'd1;
                        if (col == 10) begin
                            col <= 4'd0;
                            row <= row + 4'd1;
                        end
                    end else begin
                        // Back substitution complete
                        result <= matrix[0][10];
                        next_state <= FINISH;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule