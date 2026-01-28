module xorbonacci_query(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [63:0] init,
    input wire [63:0] l,
    input wire [63:0] r,
    output reg [63:0] result,
    output reg done
);

    // Parameters
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_L = 3'd1;
    localparam [2:0] COMPUTE_R = 3'd2;
    localparam [2:0] FINAL_XOR = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State and control signals
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Initial terms (scaled to 8 bits)
    reg [7:0] init_terms [0:7];
    integer i;

    // Matrix exponentiation variables
    reg [7:0] exponent [0:7];
    reg [7:0] base_matrix [0:7][0:7];
    reg [7:0] result_matrix [0:7][0:7];
    reg [7:0] identity_matrix [0:7][0:7];
    reg [7:0] temp_matrix [0:7][0:7];

    // Prefix sum variables
    reg [7:0] prefix_l_minus_1 [0:7];
    reg [7:0] prefix_r [0:7];
    reg [7:0] final_result [0:7];

    // Current exponentiation target
    reg [63:0] current_target;
    reg [63:0] current_exponent;

    // Initialize identity matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                identity_matrix[i][i] <= 1'b1;
                if (i < 7) begin
                    identity_matrix[i][i+1] <= 1'b1;
                end
            end
        end
    end

    // Initialize base matrix (transition matrix)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                base_matrix[0][i] <= init_terms[7-i];
            end
            for (i = 1; i < 8; i = i + 1) begin
                base_matrix[i][i-1] <= 1'b1;
            end
        end
    end

    // Matrix multiplication (GF(2))
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            temp_matrix[i][0] = ^(base_matrix[i][0] & result_matrix[0][0], base_matrix[i][1] & result_matrix[1][0], 
                                base_matrix[i][2] & result_matrix[2][0], base_matrix[i][3] & result_matrix[3][0],
                                base_matrix[i][4] & result_matrix[4][0], base_matrix[i][5] & result_matrix[5][0],
                                base_matrix[i][6] & result_matrix[6][0], base_matrix[i][7] & result_matrix[7][0]);
            temp_matrix[i][1] = ^(base_matrix[i][0] & result_matrix[0][1], base_matrix[i][1] & result_matrix[1][1], 
                                base_matrix[i][2] & result_matrix[2][1], base_matrix[i][3] & result_matrix[3][1],
                                base_matrix[i][4] & result_matrix[4][1], base_matrix[i][5] & result_matrix[5][1],
                                base_matrix[i][6] & result_matrix[6][1], base_matrix[i][7] & result_matrix[7][1]);
            temp_matrix[i][2] = ^(base_matrix[i][0] & result_matrix[0][2], base_matrix[i][1] & result_matrix[1][2], 
                                base_matrix[i][2] & result_matrix[2][2], base_matrix[i][3] & result_matrix[3][2],
                                base_matrix[i][4] & result_matrix[4][2], base_matrix[i][5] & result_matrix[5][2],
                                base_matrix[i][6] & result_matrix[6][2], base_matrix[i][7] & result_matrix[7][2]);
            temp_matrix[i][3] = ^(base_matrix[i][0] & result_matrix[0][3], base_matrix[i][1] & result_matrix[1][3], 
                                base_matrix[i][2] & result_matrix[2][3], base_matrix[i][3] & result_matrix[3][3],
                                base_matrix[i][4] & result_matrix[4][3], base_matrix[i][5] & result_matrix[5][3],
                                base_matrix[i][6] & result_matrix[6][3], base_matrix[i][7] & result_matrix[7][3]);
            temp_matrix[i][4] = ^(base_matrix[i][0] & result_matrix[0][4], base_matrix[i][1] & result_matrix[1][4], 
                                base_matrix[i][2] & result_matrix[2][4], base_matrix[i][3] & result_matrix[3][4],
                                base_matrix[i][4] & result_matrix[4][4], base_matrix[i][5] & result_matrix[5][4],
                                base_matrix[i][6] & result_matrix[6][4], base_matrix[i][7] & result_matrix[7][4]);
            temp_matrix[i][5] = ^(base_matrix[i][0] & result_matrix[0][5], base_matrix[i][1] & result_matrix[1][5], 
                                base_matrix[i][2] & result_matrix[2][5], base_matrix[i][3] & result_matrix[3][5],
                                base_matrix[i][4] & result_matrix[4][5], base_matrix[i][5] & result_matrix[5][5],
                                base_matrix[i][6] & result_matrix[6][5], base_matrix[i][7] & result_matrix[7][5]);
            temp_matrix[i][6] = ^(base_matrix[i][0] & result_matrix[0][6], base_matrix[i][1] & result_matrix[1][6], 
                                base_matrix[i][2] & result_matrix[2][6], base_matrix[i][3] & result_matrix[3][6],
                                base_matrix[i][4] & result_matrix[4][6], base_matrix[i][5] & result_matrix[5][6],
                                base_matrix[i][6] & result_matrix[6][6], base_matrix[i][7] & result_matrix[7][6]);
            temp_matrix[i][7] = ^(base_matrix[i][0] & result_matrix[0][7], base_matrix[i][1] & result_matrix[1][7], 
                                base_matrix[i][2] & result_matrix[2][7], base_matrix[i][3] & result_matrix[3][7],
                                base_matrix[i][4] & result_matrix[4][7], base_matrix[i][5] & result_matrix[5][7],
                                base_matrix[i][6] & result_matrix[6][7], base_matrix[i][7] & result_matrix[7][7]);
        end
    end

    // Matrix exponentiation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                result_matrix[i][i] <= 1'b1;
            end
        end else if (state == COMPUTE_L || state == COMPUTE_R) begin
            if (current_exponent[0]) begin
                // Multiply result by base
                for (i = 0; i < 8; i = i + 1) begin
                    result_matrix[i][0] <= temp_matrix[i][0];
                    result_matrix[i][1] <= temp_matrix[i][1];
                    result_matrix[i][2] <= temp_matrix[i][2];
                    result_matrix[i][3] <= temp_matrix[i][3];
                    result_matrix[i][4] <= temp_matrix[i][4];
                    result_matrix[i][5] <= temp_matrix[i][5];
                    result_matrix[i][6] <= temp_matrix[i][6];
                    result_matrix[i][7] <= temp_matrix[i][7];
                end
            end
            current_exponent <= current_exponent >> 1;
            if (current_exponent != 64'd0) begin
                // Square the base matrix
                for (i = 0; i < 8; i = i + 1) begin
                    base_matrix[i][0] <= temp_matrix[i][0];
                    base_matrix[i][1] <= temp_matrix[i][1];
                    base_matrix[i][2] <= temp_matrix[i][2];
                    base_matrix[i][3] <= temp_matrix[i][3];
                    base_matrix[i][4] <= temp_matrix[i][4];
                    base_matrix[i][5] <= temp_matrix[i][5];
                    base_matrix[i][6] <= temp_matrix[i][6];
                    base_matrix[i][7] <= temp_matrix[i][7];
                end
            end
        end
    end

    // Compute prefix sum
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                prefix_l_minus_1[i] <= 8'd0;
                prefix_r[i] <= 8'd0;
                final_result[i] <= 8'd0;
            end
        end else if (state == COMPUTE_L || state == COMPUTE_R) begin
            if (current_exponent == 64'd0) begin
                // Multiply result_matrix by initial vector
                if (state == COMPUTE_L) begin
                    prefix_l_minus_1[0] <= ^(result_matrix[0][0] & init_terms[0], result_matrix[0][1] & init_terms[1],
                                           result_matrix[0][2] & init_terms[2], result_matrix[0][3] & init_terms[3],
                                           result_matrix[0][4] & init_terms[4], result_matrix[0][5] & init_terms[5],
                                           result_matrix[0][6] & init_terms[6], result_matrix[0][7] & init_terms[7]);
                    prefix_l_minus_1[1] <= ^(result_matrix[1][0] & init_terms[0], result_matrix[1][1] & init_terms[1],
                                           result_matrix[1][2] & init_terms[2], result_matrix[1][3] & init_terms[3],
                                           result_matrix[1][4] & init_terms[4], result_matrix[1][5] & init_terms[5],
                                           result_matrix[1][6] & init_terms[6], result_matrix[1][7] & init_terms[7]);
                    prefix_l_minus_1[2] <= ^(result_matrix[2][0] & init_terms[0], result_matrix[2][1] & init_terms[1],
                                           result_matrix[2][2] & init_terms[2], result_matrix[2][3] & init_terms[3],
                                           result_matrix[2][4] & init_terms[4], result_matrix[2][5] & init_terms[5],
                                           result_matrix[2][6] & init_terms[6], result_matrix[2][7] & init_terms[7]);
                    prefix_l_minus_1[3] <= ^(result_matrix[3][0] & init_terms[0], result_matrix[3][1] & init_terms[1],
                                           result_matrix[3][2] & init_terms[2], result_matrix[3][3] & init_terms[3],
                                           result_matrix[3][4] & init_terms[4], result_matrix[3][5] & init_terms[5],
                                           result_matrix[3][6] & init_terms[6], result_matrix[3][7] & init_terms[7]);
                    prefix_l_minus_1[4] <= ^(result_matrix[4][0] & init_terms[0], result_matrix[4][1] & init_terms[1],
                                           result_matrix[4][2] & init_terms[2], result_matrix[4][3] & init_terms[3],
                                           result_matrix[4][4] & init_terms[4], result_matrix[4][5] & init_terms[5],
                                           result_matrix[4][6] & init_terms[6], result_matrix[4][7] & init_terms[7]);
                    prefix_l_minus_1[5] <= ^(result_matrix[5][0] & init_terms[0], result_matrix[5][1] & init_terms[1],
                                           result_matrix[5][2] & init_terms[2], result_matrix[5][3] & init_terms[3],
                                           result_matrix[5][4] & init_terms[4], result_matrix[5][5] & init_terms[5],
                                           result_matrix[5][6] & init_terms[6], result_matrix[5][7] & init_terms[7]);
                    prefix_l_minus_1[6] <= ^(result_matrix[6][0] & init_terms[0], result_matrix[6][1] & init_terms[1],
                                           result_matrix[6][2] & init_terms[2], result_matrix[6][3] & init_terms[3],
                                           result_matrix[6][4] & init_terms[4], result_matrix[6][5] & init_terms[5],
                                           result_matrix[6][6] & init_terms[6], result_matrix[6][7] & init_terms[7]);
                    prefix_l_minus_1[7] <= ^(result_matrix[7][0] & init_terms[0], result_matrix[7][1] & init_terms[1],
                                           result_matrix[7][2] & init_terms[2], result_matrix[7][3] & init_terms[3],
                                           result_matrix[7][4] & init_terms[4], result_matrix[7][5] & init_terms[5],
                                           result_matrix[7][6] & init_terms[6], result_matrix[7][7] & init_terms[7]);
                end else begin
                    prefix_r[0] <= ^(result_matrix[0][0] & init_terms[0], result_matrix[0][1] & init_terms[1],
                                     result_matrix[0][2] & init_terms[2], result_matrix[0][3] & init_terms[3],
                                     result_matrix[0][4] & init_terms[4], result_matrix[0][5] & init_terms[5],
                                     result_matrix[0][6] & init_terms[6], result_matrix[0][7] & init_terms[7]);
                    prefix_r[1] <= ^(result_matrix[1][0] & init_terms[0], result_matrix[1][1] & init_terms[1],
                                     result_matrix[1][2] & init_terms[2], result_matrix[1][3] & init_terms[3],
                                     result_matrix[1][4] & init_terms[4], result_matrix[1][5] & init_terms[5],
                                     result_matrix[1][6] & init_terms[6], result_matrix[1][7] & init_terms[7]);
                    prefix_r[2] <= ^(result_matrix[2][0] & init_terms[0], result_matrix[2][1] & init_terms[1],
                                     result_matrix[2][2] & init_terms[2], result_matrix[2][3] & init_terms[3],
                                     result_matrix[2][4] & init_terms[4], result_matrix[2][5] & init_terms[5],
                                     result_matrix[2][6] & init_terms[6], result_matrix[2][7] & init_terms[7]);
                    prefix_r[3] <= ^(result_matrix[3][0] & init_terms[0], result_matrix[3][1] & init_terms[1],
                                     result_matrix[3][2] & init_terms[2], result_matrix[3][3] & init_terms[3],
                                     result_matrix[3][4] & init_terms[4], result_matrix[3][5] & init_terms[5],
                                     result_matrix[3][6] & init_terms[6], result_matrix[3][7] & init_terms[7]);
                    prefix_r[4] <= ^(result_matrix[4][0] & init_terms[0], result_matrix[4][1] & init_terms[1],
                                     result_matrix[4][2] & init_terms[2], result_matrix[4][3] & init_terms[3],
                                     result_matrix[4][4] & init_terms[4], result_matrix[4][5] & init_terms[5],
                                     result_matrix[4][6] & init_terms[6], result_matrix[4][7] & init_terms[7]);
                    prefix_r[5] <= ^(result_matrix[5][0] & init_terms[0], result_matrix[5][1] & init_terms[1],
                                     result_matrix[5][2] & init_terms[2], result_matrix[5][3] & init_terms[3],
                                     result_matrix[5][4] & init_terms[4], result_matrix[5][5] & init_terms[5],
                                     result_matrix[5][6] & init_terms[6], result_matrix[5][7] & init_terms[7]);
                    prefix_r[6] <= ^(result_matrix[6][0] & init_terms[0], result_matrix[6][1] & init_terms[1],
                                     result_matrix[6][2] & init_terms[2], result_matrix[6][3] & init_terms[3],
                                     result_matrix[6][4] & init_terms[4], result_matrix[6][5] & init_terms[5],
                                     result_matrix[6][6] & init_terms[6], result_matrix[6][7] & init_terms[7]);
                    prefix_r[7] <= ^(result_matrix[7][0] & init_terms[0], result_matrix[7][1] & init_terms[1],
                                     result_matrix[7][2] & init_terms[2], result_matrix[7][3] & init_terms[3],
                                     result_matrix[7][4] & init_terms[4], result_matrix[7][5] & init_terms[5],
                                     result_matrix[7][6] & init_terms[6], result_matrix[7][7] & init_terms[7]);
                end
            end
        end
    end

    // Final XOR
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                final_result[i] <= 8'd0;
            end
        end else if (state == FINAL_XOR) begin
            for (i = 0; i < 8; i = i + 1) begin
                final_result[i] <= prefix_l_minus_1[i] ^ prefix_r[i];
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                init_terms[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    // Load initial terms
                    for (i = 0; i < 8; i = i + 1) begin
                        init_terms[i] = init[8*i +: 8];
                    end
                    current_target = l - 64'd1;
                    current_exponent = current_target;
                    next_state = COMPUTE_L;
                end
            end
            COMPUTE_L: begin
                if (current_exponent == 64'd0) begin
                    current_target = r;
                    current_exponent = current_target;
                    next_state = COMPUTE_R;
                end
            end
            COMPUTE_R: begin
                if (current_exponent == 64'd0) begin
                    next_state = FINAL_XOR;
                end
            end
            FINAL_XOR: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 64'd0;
        end else if (state == DONE_STATE) begin
            result <= {final_result[7], final_result[6], final_result[5], final_result[4],
                      final_result[3], final_result[2], final_result[1], final_result[0]};
        end
    end

endmodule