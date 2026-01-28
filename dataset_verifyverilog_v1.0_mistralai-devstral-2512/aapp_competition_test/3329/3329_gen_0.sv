module CircularBinarySequences(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] N,
    input wire [3:0] K,
    input wire [99:0] target_seq,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] COMPUTE_ROTATIONS = 4'd2;
    localparam [3:0] MATRIX_EXPONENTIATION = 4'd3;
    localparam [3:0] SOLVE_SYSTEM = 4'd4;
    localparam [3:0] COUNT_SOLUTIONS = 4'd5;
    localparam [3:0] FINISH = 4'd6;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Internal signals
    reg [6:0] n_reg;
    reg [3:0] k_reg;
    reg [99:0] target_reg;
    reg [99:0] rotated_target [0:99];
    reg [99:0] current_target;
    reg [99:0] matrix [0:99];
    reg [99:0] temp_matrix [0:99];
    reg [99:0] solution_vector;
    reg [3:0] rotation_index;
    reg [3:0] row_index;
    reg [3:0] col_index;
    reg [3:0] bit_index;
    reg [3:0] null_space_dim;
    reg [15:0] solution_count;
    reg [15:0] total_count;
    reg [3:0] exponent_bit;
    reg [3:0] current_bit;
    reg [3:0] pivot_row;
    reg [3:0] pivot_col;
    reg [3:0] elimination_row;
    reg [3:0] elimination_col;
    reg [3:0] solution_row;
    reg [3:0] solution_col;
    reg [3:0] solution_bit;
    reg [3:0] solution_index;
    reg [3:0] solution_pivot;
    reg [3:0] solution_pivot_row;
    reg [3:0] solution_pivot_col;
    reg [3:0] solution_pivot_bit;
    reg [3:0] solution_pivot_index;
    reg [3:0] solution_pivot_count;
    reg [3:0] solution_pivot_total;
    reg [3:0] solution_pivot_max;
    reg [3:0] solution_pivot_min;
    reg [3:0] solution_pivot_avg;
    reg [3:0] solution_pivot_sum;
    reg [3:0] solution_pivot_product;
    reg [3:0] solution_pivot_quotient;
    reg [3:0] solution_pivot_remainder;
    reg [3:0] solution_pivot_modulus;
    reg [3:0] solution_pivot_exponent;
    reg [3:0] solution_pivot_base;
    reg [3:0] solution_pivot_result;
    reg [3:0] solution_pivot_temp;
    reg [3:0] solution_pivot_temp2;
    reg [3:0] solution_pivot_temp3;
    reg [3:0] solution_pivot_temp4;
    reg [3:0] solution_pivot_temp5;
    reg [3:0] solution_pivot_temp6;
    reg [3:0] solution_pivot_temp7;
    reg [3:0] solution_pivot_temp8;
    reg [3:0] solution_pivot_temp9;
    reg [3:0] solution_pivot_temp10;
    reg [3:0] solution_pivot_temp11;
    reg [3:0] solution_pivot_temp12;
    reg [3:0] solution_pivot_temp13;
    reg [3:0] solution_pivot_temp14;
    reg [3:0] solution_pivot_temp15;
    reg [3:0] solution_pivot_temp16;
    reg [3:0] solution_pivot_temp17;
    reg [3:0] solution_pivot_temp18;
    reg [3:0] solution_pivot_temp19;
    reg [3:0] solution_pivot_temp20;
    reg [3:0] solution_pivot_temp21;
    reg [3:0] solution_pivot_temp22;
    reg [3:0] solution_pivot_temp23;
    reg [3:0] solution_pivot_temp24;
    reg [3:0] solution_pivot_temp25;
    reg [3:0] solution_pivot_temp26;
    reg [3:0] solution_pivot_temp27;
    reg [3:0] solution_pivot_temp28;
    reg [3:0] solution_pivot_temp29;
    reg [3:0] solution_pivot_temp30;
    reg [3:0] solution_pivot_temp31;
    reg [3:0] solution_pivot_temp32;
    reg [3:0] solution_pivot_temp33;
    reg [3:0] solution_pivot_temp34;
    reg [3:0] solution_pivot_temp35;
    reg [3:0] solution_pivot_temp36;
    reg [3:0] solution_pivot_temp37;
    reg [3:0] solution_pivot_temp38;
    reg [3:0] solution_pivot_temp39;
    reg [3:0] solution_pivot_temp40;
    reg [3:0] solution_pivot_temp41;
    reg [3:0] solution_pivot_temp42;
    reg [3:0] solution_pivot_temp43;
    reg [3:0] solution_pivot_temp44;
    reg [3:0] solution_pivot_temp45;
    reg [3:0] solution_pivot_temp46;
    reg [3:0] solution_pivot_temp47;
    reg [3:0] solution_pivot_temp48;
    reg [3:0] solution_pivot_temp49;
    reg [3:0] solution_pivot_temp50;
    reg [3:0] solution_pivot_temp51;
    reg [3:0] solution_pivot_temp52;
    reg [3:0] solution_pivot_temp53;
    reg [3:0] solution_pivot_temp54;
    reg [3:0] solution_pivot_temp55;
    reg [3:0] solution_pivot_temp56;
    reg [3:0] solution_pivot_temp57;
    reg [3:0] solution_pivot_temp58;
    reg [3:0] solution_pivot_temp59;
    reg [3:0] solution_pivot_temp60;
    reg [3:0] solution_pivot_temp61;
    reg [3:0] solution_pivot_temp62;
    reg [3:0] solution_pivot_temp63;
    reg [3:0] solution_pivot_temp64;
    reg [3:0] solution_pivot_temp65;
    reg [3:0] solution_pivot_temp66;
    reg [3:0] solution_pivot_temp67;
    reg [3:0] solution_pivot_temp68;
    reg [3:0] solution_pivot_temp69;
    reg [3:0] solution_pivot_temp70;
    reg [3:0] solution_pivot_temp71;
    reg [3:0] solution_pivot_temp72;
    reg [3:0] solution_pivot_temp73;
    reg [3:0] solution_pivot_temp74;
    reg [3:0] solution_pivot_temp75;
    reg [3:0] solution_pivot_temp76;
    reg [3:0] solution_pivot_temp77;
    reg [3:0] solution_pivot_temp78;
    reg [3:0] solution_pivot_temp79;
    reg [3:0] solution_pivot_temp80;
    reg [3:0] solution_pivot_temp81;
    reg [3:0] solution_pivot_temp82;
    reg [3:0] solution_pivot_temp83;
    reg [3:0] solution_pivot_temp84;
    reg [3:0] solution_pivot_temp85;
    reg [3:0] solution_pivot_temp86;
    reg [3:0] solution_pivot_temp87;
    reg [3:0] solution_pivot_temp88;
    reg [3:0] solution_pivot_temp89;
    reg [3:0] solution_pivot_temp90;
    reg [3:0] solution_pivot_temp91;
    reg [3:0] solution_pivot_temp92;
    reg [3:0] solution_pivot_temp93;
    reg [3:0] solution_pivot_temp94;
    reg [3:0] solution_pivot_temp95;
    reg [3:0] solution_pivot_temp96;
    reg [3:0] solution_pivot_temp97;
    reg [3:0] solution_pivot_temp98;
    reg [3:0] solution_pivot_temp99;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 7'd0;
            k_reg <= 4'd0;
            target_reg <= 100'd0;
            rotation_index <= 4'd0;
            row_index <= 4'd0;
            col_index <= 4'd0;
            bit_index <= 4'd0;
            null_space_dim <= 4'd0;
            solution_count <= 16'd0;
            total_count <= 16'd0;
            exponent_bit <= 4'd0;
            current_bit <= 4'd0;
            pivot_row <= 4'd0;
            pivot_col <= 4'd0;
            elimination_row <= 4'd0;
            elimination_col <= 4'd0;
            solution_row <= 4'd0;
            solution_col <= 4'd0;
            solution_bit <= 4'd0;
            solution_index <= 4'd0;
            solution_pivot <= 4'd0;
            solution_pivot_row <= 4'd0;
            solution_pivot_col <= 4'd0;
            solution_pivot_bit <= 4'd0;
            solution_pivot_index <= 4'd0;
            solution_pivot_count <= 4'd0;
            solution_pivot_total <= 4'd0;
            solution_pivot_max <= 4'd0;
            solution_pivot_min <= 4'd0;
            solution_pivot_avg <= 4'd0;
            solution_pivot_sum <= 4'd0;
            solution_pivot_product <= 4'd0;
            solution_pivot_quotient <= 4'd0;
            solution_pivot_remainder <= 4'd0;
            solution_pivot_modulus <= 4'd0;
            solution_pivot_exponent <= 4'd0;
            solution_pivot_base <= 4'd0;
            solution_pivot_result <= 4'd0;
            solution_pivot_temp <= 4'd0;
            solution_pivot_temp2 <= 4'd0;
            solution_pivot_temp3 <= 4'd0;
            solution_pivot_temp4 <= 4'd0;
            solution_pivot_temp5 <= 4'd0;
            solution_pivot_temp6 <= 4'd0;
            solution_pivot_temp7 <= 4'd0;
            solution_pivot_temp8 <= 4'd0;
            solution_pivot_temp9 <= 4'd0;
            solution_pivot_temp10 <= 4'd0;
            solution_pivot_temp11 <= 4'd0;
            solution_pivot_temp12 <= 4'd0;
            solution_pivot_temp13 <= 4'd0;
            solution_pivot_temp14 <= 4'd0;
            solution_pivot_temp15 <= 4'd0;
            solution_pivot_temp16 <= 4'd0;
            solution_pivot_temp17 <= 4'd0;
            solution_pivot_temp18 <= 4'd0;
            solution_pivot_temp19 <= 4'd0;
            solution_pivot_temp20 <= 4'd0;
            solution_pivot_temp21 <= 4'd0;
            solution_pivot_temp22 <= 4'd0;
            solution_pivot_temp23 <= 4'd0;
            solution_pivot_temp24 <= 4'd0;
            solution_pivot_temp25 <= 4'd0;
            solution_pivot_temp26 <= 4'd0;
            solution_pivot_temp27 <= 4'd0;
            solution_pivot_temp28 <= 4'd0;
            solution_pivot_temp29 <= 4'd0;
            solution_pivot_temp30 <= 4'd0;
            solution_pivot_temp31 <= 4'd0;
            solution_pivot_temp32 <= 4'd0;
            solution_pivot_temp33 <= 4'd0;
            solution_pivot_temp34 <= 4'd0;
            solution_pivot_temp35 <= 4'd0;
            solution_pivot_temp36 <= 4'd0;
            solution_pivot_temp37 <= 4'd0;
            solution_pivot_temp38 <= 4'd0;
            solution_pivot_temp39 <= 4'd0;
            solution_pivot_temp40 <= 4'd0;
            solution_pivot_temp41 <= 4'd0;
            solution_pivot_temp42 <= 4'd0;
            solution_pivot_temp43 <= 4'd0;
            solution_pivot_temp44 <= 4'd0;
            solution_pivot_temp45 <= 4'd0;
            solution_pivot_temp46 <= 4'd0;
            solution_pivot_temp47 <= 4'd0;
            solution_pivot_temp48 <= 4'd0;
            solution_pivot_temp49 <= 4'd0;
            solution_pivot_temp50 <= 4'd0;
            solution_pivot_temp51 <= 4'd0;
            solution_pivot_temp52 <= 4'd0;
            solution_pivot_temp53 <= 4'd0;
            solution_pivot_temp54 <= 4'd0;
            solution_pivot_temp55 <= 4'd0;
            solution_pivot_temp56 <= 4'd0;
            solution_pivot_temp57 <= 4'd0;
            solution_pivot_temp58 <= 4'd0;
            solution_pivot_temp59 <= 4'd0;
            solution_pivot_temp60 <= 4'd0;
            solution_pivot_temp61 <= 4'd0;
            solution_pivot_temp62 <= 4'd0;
            solution_pivot_temp63 <= 4'd0;
            solution_pivot_temp64 <= 4'd0;
            solution_pivot_temp65 <= 4'd0;
            solution_pivot_temp66 <= 4'd0;
            solution_pivot_temp67 <= 4'd0;
            solution_pivot_temp68 <= 4'd0;
            solution_pivot_temp69 <= 4'd0;
            solution_pivot_temp70 <= 4'd0;
            solution_pivot_temp71 <= 4'd0;
            solution_pivot_temp72 <= 4'd0;
            solution_pivot_temp73 <= 4'd0;
            solution_pivot_temp74 <= 4'd0;
            solution_pivot_temp75 <= 4'd0;
            solution_pivot_temp76 <= 4'd0;
            solution_pivot_temp77 <= 4'd0;
            solution_pivot_temp78 <= 4'd0;
            solution_pivot_temp79 <= 4'd0;
            solution_pivot_temp80 <= 4'd0;
            solution_pivot_temp81 <= 4'd0;
            solution_pivot_temp82 <= 4'd0;
            solution_pivot_temp83 <= 4'd0;
            solution_pivot_temp84 <= 4'd0;
            solution_pivot_temp85 <= 4'd0;
            solution_pivot_temp86 <= 4'd0;
            solution_pivot_temp87 <= 4'd0;
            solution_pivot_temp88 <= 4'd0;
            solution_pivot_temp89 <= 4'd0;
            solution_pivot_temp90 <= 4'd0;
            solution_pivot_temp91 <= 4'd0;
            solution_pivot_temp92 <= 4'd0;
            solution_pivot_temp93 <= 4'd0;
            solution_pivot_temp94 <= 4'd0;
            solution_pivot_temp95 <= 4'd0;
            solution_pivot_temp96 <= 4'd0;
            solution_pivot_temp97 <= 4'd0;
            solution_pivot_temp98 <= 4'd0;
            solution_pivot_temp99 <= 4'd0;

            // Initialize matrix and rotated targets
            integer i;
            for (i = 0; i < 100; i = i + 1) begin
                matrix[i] <= 100'd0;
                temp_matrix[i] <= 100'd0;
                rotated_target[i] <= 100'd0;
            end
            current_target <= 100'd0;
            solution_vector <= 100'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= N;
                        k_reg <= K;
                        target_reg <= target_seq;
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize identity matrix
                    integer i;
                    for (i = 0; i < 100; i = i + 1) begin
                        if (i < n_reg) begin
                            matrix[i] <= 100'd0;
                            matrix[i][i] <= 1'b1;
                        end else begin
                            matrix[i] <= 100'd0;
                        end
                    end
                    next_state <= COMPUTE_ROTATIONS;
                end

                COMPUTE_ROTATIONS: begin
                    // Compute all rotations of target
                    integer i, j;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        for (j = 0; j < n_reg; j = j + 1) begin
                            rotated_target[i][j] <= target_reg[(j + i) % n_reg];
                        end
                    end
                    rotation_index <= 4'd0;
                    next_state <= MATRIX_EXPONENTIATION;
                end

                MATRIX_EXPONENTIATION: begin
                    // Matrix exponentiation using binary representation of K
                    integer i, j;
                    reg [99:0] temp_row;

                    // Initialize temp_matrix as identity
                    for (i = 0; i < 100; i = i + 1) begin
                        if (i < n_reg) begin
                            temp_matrix[i] <= 100'd0;
                            temp_matrix[i][i] <= 1'b1;
                        end else begin
                            temp_matrix[i] <= 100'd0;
                        end
                    end

                    // Process each bit of K
                    for (exponent_bit = 0; exponent_bit < 4; exponent_bit = exponent_bit + 1) begin
                        if (k_reg[exponent_bit]) begin
                            // Multiply temp_matrix by current matrix
                            for (i = 0; i < n_reg; i = i + 1) begin
                                temp_row <= 100'd0;
                                for (j = 0; j < n_reg; j = j + 1) begin
                                    if (temp_matrix[i][j]) begin
                                        temp_row <= temp_row ^ matrix[j];
                                    end
                                end
                                temp_matrix[i] <= temp_row;
                            end
                        end

                        // Square the matrix for next bit
                        for (i = 0; i < n_reg; i = i + 1) begin
                            temp_row <= 100'd0;
                            for (j = 0; j < n_reg; j = j + 1) begin
                                if (matrix[i][j]) begin
                                    temp_row <= temp_row ^ matrix[j];
                                end
                            end
                            matrix[i] <= temp_row;
                        end
                    end

                    // Copy result back to matrix
                    for (i = 0; i < 100; i = i + 1) begin
                        matrix[i] <= temp_matrix[i];
                    end

                    next_state <= SOLVE_SYSTEM;
                end

                SOLVE_SYSTEM: begin
                    // Solve matrix * x = current_target for each rotation
                    integer i, j, k;
                    reg [99:0] temp_row;
                    reg pivot_found;

                    // Gaussian elimination
                    pivot_row <= 4'd0;
                    pivot_col <= 4'd0;

                    // Forward elimination
                    for (pivot_col = 0; pivot_col < n_reg; pivot_col = pivot_col + 1) begin
                        pivot_found <= 1'b0;
                        for (pivot_row = pivot_col; pivot_row < n_reg; pivot_row = pivot_row + 1) begin
                            if (matrix[pivot_row][pivot_col]) begin
                                pivot_found <= 1'b1;
                                break;
                            end
                        end

                        if (pivot_found) begin
                            // Swap rows if needed
                            if (pivot_row != pivot_col) begin
                                temp_row <= matrix[pivot_col];
                                matrix[pivot_col] <= matrix[pivot_row];
                                matrix[pivot_row] <= temp_row;
                            end

                            // Eliminate column
                            for (elimination_row = pivot_col + 1; elimination_row < n_reg; elimination_row = elimination_row + 1) begin
                                if (matrix[elimination_row][pivot_col]) begin
                                    matrix[elimination_row] <= matrix[elimination_row] ^ matrix[pivot_col];
                                end
                            end
                        end
                    end

                    // Back substitution
                    null_space_dim <= 4'd0;
                    for (i = 0; i < n_reg; i = i + 1) begin
                        pivot_found <= 1'b0;
                        for (j = 0; j < n_reg; j = j + 1) begin
                            if (matrix[i][j]) begin
                                pivot_found <= 1'b1;
                                break;
                            end
                        end
                        if (!pivot_found) begin
                            null_space_dim <= null_space_dim + 4'd1;
                        end
                    end

                    // Compute solution count: 2^null_space_dim
                    solution_count <= 16'd1 << null_space_dim;
                    total_count <= total_count + solution_count;

                    // Move to next rotation
                    rotation_index <= rotation_index + 4'd1;
                    if (rotation_index >= n_reg) begin
                        next_state <= FINISH;
                    end else begin
                        current_target <= rotated_target[rotation_index];
                        next_state <= SOLVE_SYSTEM;
                    end
                end

                FINISH: begin
                    result <= total_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b1;
        end
    end

endmodule