module arcade_expected_value (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_holes,
    input [31:0] payouts_in,
    input [31:0] probs_in,
    input [2:0] prob_idx,
    output reg [31:0] expected_value,
    output reg done,
    output reg ready_for_input
);

    // Parameters
    localparam MAX_HOLES = 10;
    localparam Q16_16_ONE = 32'h00010000;
    localparam Q16_16_HALF = 32'h00008000;

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        LOAD_PAYOUTS,
        LOAD_PROBS,
        BUILD_MATRIX,
        ELIMINATION,
        BACK_SUBSTITUTION,
        DONE_STATE
    } state_t;

    // Internal registers
    state_t current_state, next_state;
    reg [5:0] hole_counter;
    reg [2:0] prob_counter;
    reg [31:0] payouts [0:MAX_HOLES-1];
    reg [31:0] probs [0:4];
    reg [63:0] matrix_A [0:MAX_HOLES-1][0:MAX_HOLES-1];
    reg [63:0] vector_b [0:MAX_HOLES-1];
    reg [63:0] solution [0:MAX_HOLES-1];
    reg [5:0] elimination_row, elimination_col;
    reg [5:0] pivot_row;
    reg [63:0] temp, max_val;
    reg [5:0] i, j, k;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            hole_counter <= 0;
            prob_counter <= 0;
            ready_for_input <= 1'b0;
            done <= 1'b0;
            expected_value <= 32'h0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_PAYOUTS;
            end
            LOAD_PAYOUTS: begin
                if (hole_counter == num_holes - 1) begin
                    next_state = LOAD_PROBS;
                    hole_counter = 0;
                end
            end
            LOAD_PROBS: begin
                if (prob_counter == 4) begin
                    next_state = BUILD_MATRIX;
                    prob_counter = 0;
                end
            end
            BUILD_MATRIX: begin
                if (hole_counter == num_holes - 1) begin
                    next_state = ELIMINATION;
                    hole_counter = 0;
                    elimination_row = 0;
                    elimination_col = 0;
                end
            end
            ELIMINATION: begin
                if (elimination_row == num_holes - 1) begin
                    next_state = BACK_SUBSTITUTION;
                    elimination_row = num_holes - 1;
                end
            end
            BACK_SUBSTITUTION: begin
                if (elimination_row == 0) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                if (start) next_state = IDLE;
            end
        endcase
    end

    // Data loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hole_counter <= 0;
            prob_counter <= 0;
        end else begin
            case (current_state)
                LOAD_PAYOUTS: begin
                    if (ready_for_input) begin
                        payouts[hole_counter] <= payouts_in;
                        hole_counter <= hole_counter + 1;
                    end
                end
                LOAD_PROBS: begin
                    if (ready_for_input) begin
                        probs[prob_idx] <= probs_in;
                        prob_counter <= prob_counter + 1;
                    end
                end
            endcase
        end
    end

    // Ready signal
    always @(*) begin
        ready_for_input = 1'b0;
        case (current_state)
            LOAD_PAYOUTS: ready_for_input = 1'b1;
            LOAD_PROBS: ready_for_input = 1'b1;
        endcase
    end

    // Matrix construction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_HOLES; i = i + 1) begin
                for (j = 0; j < MAX_HOLES; j = j + 1) begin
                    matrix_A[i][j] <= 64'h0;
                end
                vector_b[i] <= 64'h0;
            end
        end else if (current_state == BUILD_MATRIX) begin
            // Diagonal element
            matrix_A[hole_counter][hole_counter] <= {32'h0, Q16_16_ONE} - {32'h0, probs[4]};
            
            // Neighbor elements (simplified for this example)
            // In a real implementation, you would need to know the actual neighbor relationships
            // This is a placeholder for the actual neighbor logic
            if (hole_counter > 0) begin
                matrix_A[hole_counter][hole_counter - 1] <= -{32'h0, probs[0]};
            end
            if (hole_counter < num_holes - 1) begin
                matrix_A[hole_counter][hole_counter + 1] <= -{32'h0, probs[1]};
            end
            
            // Vector b
            vector_b[hole_counter] <= {32'h0, payouts[hole_counter]};
            
            hole_counter <= hole_counter + 1;
        end
    end

    // Gaussian elimination
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            elimination_row <= 0;
            elimination_col <= 0;
        end else if (current_state == ELIMINATION) begin
            if (elimination_col < num_holes) begin
                // Partial pivoting
                max_val = matrix_A[elimination_row][elimination_col];
                pivot_row = elimination_row;
                for (i = elimination_row + 1; i < num_holes; i = i + 1) begin
                    if (matrix_A[i][elimination_col] > max_val) begin
                        max_val = matrix_A[i][elimination_col];
                        pivot_row = i;
                    end
                end
                
                // Swap rows if needed
                if (pivot_row != elimination_row) begin
                    for (j = 0; j < num_holes; j = j + 1) begin
                        temp = matrix_A[elimination_row][j];
                        matrix_A[elimination_row][j] = matrix_A[pivot_row][j];
                        matrix_A[pivot_row][j] = temp;
                    end
                    temp = vector_b[elimination_row];
                    vector_b[elimination_row] = vector_b[pivot_row];
                    vector_b[pivot_row] = temp;
                end
                
                // Elimination
                for (i = elimination_row + 1; i < num_holes; i = i + 1) begin
                    if (matrix_A[i][elimination_col] != 0) begin
                        temp = matrix_A[i][elimination_col] / matrix_A[elimination_row][elimination_col];
                        for (j = elimination_col; j < num_holes; j = j + 1) begin
                            matrix_A[i][j] = matrix_A[i][j] - temp * matrix_A[elimination_row][j];
                        end
                        vector_b[i] = vector_b[i] - temp * vector_b[elimination_row];
                    end
                end
                
                elimination_col <= elimination_col + 1;
                if (elimination_col == num_holes) begin
                    elimination_row <= elimination_row + 1;
                    elimination_col <= elimination_row;
                end
            end
        end
    end

    // Back substitution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_HOLES; i = i + 1) begin
                solution[i] <= 64'h0;
            end
        end else if (current_state == BACK_SUBSTITUTION) begin
            solution[elimination_row] = vector_b[elimination_row];
            for (j = elimination_row + 1; j < num_holes; j = j + 1) begin
                solution[elimination_row] = solution[elimination_row] - matrix_A[elimination_row][j] * solution[j];
            end
            solution[elimination_row] = solution[elimination_row] / matrix_A[elimination_row][elimination_row];
            
            elimination_row <= elimination_row - 1;
            if (elimination_row == 0) begin
                expected_value <= solution[0][31:0];
                done <= 1'b1;
            end
        end else if (current_state == DONE_STATE) begin
            done <= 1'b0;
        end
    end

endmodule