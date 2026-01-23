module arcade_expected(
    input wire clk,
    input wire rst_n,
    input wire start,
    input signed [15:0] v [0:9],
    input [15:0] p0 [0:9],
    input [15:0] p1 [0:9],
    input [15:0] p2 [0:9],
    input [15:0] p3 [0:9],
    input [15:0] p4 [0:9],
    output reg signed [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] SETUP       = 4'd1;
    localparam [3:0] PIVOT       = 4'd2;
    localparam [3:0] ELIMINATE   = 4'd3;
    localparam [3:0] BACKSUB     = 4'd4;
    localparam [3:0] FINISH      = 4'd5;

    reg [3:0] state;
    reg [3:0] next_state;

    // Matrix size: 10 equations, 11 columns (10 coeff + 1 RHS)
    // Using 48-bit for fixed-point operations
    reg signed [47:0] matrix [0:9][0:10];
    reg signed [47:0] x [0:9];

    // Counters and indices
    reg [3:0] i, j, k;  // Iteration variables
    reg [3:0] pivot_row;
    reg signed [47:0] max_val;
    reg signed [47:0] temp;
    reg signed [47:0] factor;
    reg signed [47:0] sum;

    // Cycle counter for timeout protection
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd2000;

    // Neighbor indices for each hole (using signed to indicate "no neighbor")
    // Signed to allow -1 for no neighbor
    reg signed [3:0] tl_idx [0:9];
    reg signed [3:0] tr_idx [0:9];
    reg signed [3:0] bl_idx [0:9];
    reg signed [3:0] br_idx [0:9];

    // Internal computation registers
    reg signed [47:0] v_q16 [0:9];
    reg signed [47:0] p_q16 [0:9][0:4];

    integer row, col;

    // Combinational logic for setup matrix values
    always @(*) begin
        // Initialize matrix coefficients
        for (row = 0; row < 10; row = row + 1) begin
            // E[row] - (probabilities * E[neighbors]) = v[row] * p4[row]
            // Diagonal: coefficient of E[row] is 1.0
            matrix[row][row] = 48'd65536;  // 1.0 in Q16.16
            
            // Right-hand side: v[row] * p4[row]
            matrix[row][10] = (v_q16[row] * p_q16[row][4]) >>> 16;
            
            // Neighbors coefficients
            if (tl_idx[row] >= 0)
                matrix[row][tl_idx[row]] = -p_q16[row][0];
            if (tr_idx[row] >= 0)
                matrix[row][tr_idx[row]] = -p_q16[row][1];
            if (bl_idx[row] >= 0)
                matrix[row][bl_idx[row]] = -p_q16[row][2];
            if (br_idx[row] >= 0)
                matrix[row][br_idx[row]] = -p_q16[row][3];
        end
    end

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 13'd0;
            
            // Reset indices
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            pivot_row <= 4'd0;
            
            // Reset all matrix elements
            for (row = 0; row < 10; row = row + 1) begin
                for (col = 0; col < 11; col = col + 1) begin
                    matrix[row][col] <= 48'd0;
                end
                x[row] <= 48'd0;
            end
            
            // Reset intermediate values
            max_val <= 48'd0;
            temp <= 48'd0;
            factor <= 48'd0;
            sum <= 48'd0;
            
            // Reset Q16.16 conversion registers
            for (row = 0; row < 10; row = row + 1) begin
                v_q16[row] <= 48'd0;
                p_q16[row][0] <= 48'd0;
                p_q16[row][1] <= 48'd0;
                p_q16[row][2] <= 48'd0;
                p_q16[row][3] <= 48'd0;
                p_q16[row][4] <= 48'd0;
            end
            
            // Reset neighbor indices
            for (row = 0; row < 10; row = row + 1) begin
                tl_idx[row] <= 4'd15;  // Invalid value
                tr_idx[row] <= 4'd15;
                bl_idx[row] <= 4'd15;
                br_idx[row] <= 4'd15;
            end
            
        end else begin
            // Normal operation
            done <= 1'b0;
            cycle_count <= cycle_count + 13'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 13'd0;
                    
                    if (start) begin
                        state <= SETUP;
                        i <= 4'd0;
                    end
                end
                
                SETUP: begin
                    // Convert inputs to Q16.16 format and set neighbor indices
                    if (i < 10) begin
                        // Signed conversion for v (Q8.8 to Q16.16)
                        v_q16[i] <= { {32{v[i][15]}}, v[i] } << 8;
                        
                        // Unsigned conversion for probabilities (Q0.16 to Q16.16)
                        p_q16[i][0] <= {32'd0, p0[i]};
                        p_q16[i][1] <= {32'd0, p1[i]};
                        p_q16[i][2] <= {32'd0, p2[i]};
                        p_q16[i][3] <= {32'd0, p3[i]};
                        p_q16[i][4] <= {32'd0, p4[i]};
                        
                        // Set neighbor indices based on N=4 mapping
                        case (i)
                            0: begin
                                tl_idx[i] <= -1;
                                tr_idx[i] <= -1;
                                bl_idx[i] <= 1;
                                br_idx[i] <= 2;
                            end
                            1: begin
                                tl_idx[i] <= 0;
                                tr_idx[i] <= -1;
                                bl_idx[i] <= 3;
                                br_idx[i] <= 4;
                            end
                            2: begin
                                tl_idx[i] <= 0;
                                tr_idx[i] <= -1;
                                bl_idx[i] <= 4;
                                br_idx[i] <= 5;
                            end
                            3: begin
                                tl_idx[i] <= 1;
                                tr_idx[i] <= 4;
                                bl_idx[i] <= 6;
                                br_idx[i] <= 7;
                            end
                            4: begin
                                tl_idx[i] <= 2;
                                tr_idx[i] <= 5;
                                bl_idx[i] <= 7;
                                br_idx[i] <= 8;
                            end
                            5: begin
                                tl_idx[i] <= -1;
                                tr_idx[i] <= -1;
                                bl_idx[i] <= 8;
                                br_idx[i] <= 9;
                            end
                            6: begin
                                tl_idx[i] <= 3;
                                tr_idx[i] <= 7;
                                bl_idx[i] <= -1;
                                br_idx[i] <= -1;
                            end
                            7: begin
                                tl_idx[i] <= 4;
                                tr_idx[i] <= 8;
                                bl_idx[i] <= -1;
                                br_idx[i] <= -1;
                            end
                            8: begin
                                tl_idx[i] <= 5;
                                tr_idx[i] <= 9;
                                bl_idx[i] <= -1;
                                br_idx[i] <= -1;
                            end
                            9: begin
                                tl_idx[i] <= -1;
                                tr_idx[i] <= -1;
                                bl_idx[i] <= -1;
                                br_idx[i] <= -1;
                            end
                            default: begin
                                tl_idx[i] <= -1;
                                tr_idx[i] <= -1;
                                bl_idx[i] <= -1;
                                br_idx[i] <= -1;
                            end
                        endcase
                        
                        i <= i + 4'd1;
                    end else begin
                        // Build matrix and move to pivoting
                        state <= PIVOT;
                        i <= 4'd0;
                    end
                end
                
                PIVOT: begin
                    // Find pivot row for column i
                    if (i < 10) begin
                        if (i == 4'd0) begin
                            // First column, initialize max_val
                            max_val <= $signed(matrix[i][i]);
                            pivot_row <= i;
                            j <= i + 4'd1;
                        end else begin
                            // Compare with other rows
                            if (j < 10) begin
                                // Use absolute value for comparison
                                temp <= ($signed(matrix[j][i]) > $signed(max_val)) ? $signed(matrix[j][i]) : max_val;
                                if ($signed(matrix[j][i]) > $signed(max_val)) begin
                                    max_val <= $signed(matrix[j][i]);
                                    pivot_row <= j;
                                end
                                j <= j + 4'd1;
                            end else begin
                                // Swap rows if needed
                                if (pivot_row != i) begin
                                    for (col = 0; col < 11; col = col + 1) begin
                                        temp <= matrix[i][col];
                                        matrix[i][col] <= matrix[pivot_row][col];
                                        matrix[pivot_row][col] <= temp;
                                    end
                                end
                                i <= i + 4'd1;
                            end
                        end
                    end else begin
                        state <= ELIMINATE;
                        i <= 4'd0;
                    end
                end
                
                ELIMINATE: begin
                    // Gaussian elimination
                    if (i < 10) begin
                        // Normalize pivot row
                        if (j < 11) begin
                            // Divide by pivot
                            if ($signed(matrix[i][i]) != 48'd0) begin
                                factor <= $signed(matrix[i][j]) / $signed(matrix[i][i]);
                            end else begin
                                factor <= 48'd0;
                            end
                            matrix[i][j] <= factor;
                            j <= j + 4'd1;
                        end else if (k < 10) begin
                            // Eliminate below
                            if (k != i) begin
                                factor <= $signed(matrix[k][i]);
                                for (col = 0; col < 11; col = col + 1) begin
                                    matrix[k][col] <= $signed(matrix[k][col]) - ($signed(matrix[i][col]) * $signed(factor));
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                            j <= i + 4'd1;
                            k <= 4'd0;
                        end
                    end else begin
                        state <= BACKSUB;
                        i <= 4'd9;
                    end
                end
                
                BACKSUB: begin
                    // Back substitution
                    if (i >= 0) begin
                        if (j < 10) begin
                            sum <= $signed(matrix[i][10]) - ($signed(matrix[i][j]) * $signed(x[j]));
                            j <= j + 4'd1;
                        end else begin
                            x[i] <= sum;
                            if (i > 0) begin
                                i <= i - 4'd1;
                                j <= i + 4'd1;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Output result (convert Q16.16 to Q16.16)
                    result <= x[0][31:0];  // Take lower 32 bits
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
                result <= 32'd0;
            end
        end
    end

endmodule