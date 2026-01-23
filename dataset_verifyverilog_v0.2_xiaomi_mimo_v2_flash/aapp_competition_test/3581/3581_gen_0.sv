module arcade_expected_value(
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

    parameter MAX_HOLES = 10;
    localparam Q16_16_ONE = 32'h00010000;
    
    // State encoding
    localparam IDLE = 0;
    localparam LOAD_PAYOUTS = 1;
    localparam LOAD_PROBS = 2;
    localparam BUILD_MATRIX = 3;
    localparam CALC_ROW_NEIGHBORS = 4;
    localparam ELIMINATION_START = 5;
    localparam ELIMINATION_OUTER = 6;
    localparam ELIMINATION_PIVOT_FIND = 7;
    localparam ELIMINATION_SWAP = 8;
    localparam ELIMINATION_FACTOR = 9;
    localparam DIV_START = 10;
    localparam WAIT_DIV = 11;
    localparam ELIMINATION_FACTOR_STORE = 12;
    localparam ELIMINATION_UPDATE = 13;
    localparam ELIMINATION_UPDATE_APPLY = 14;
    localparam ELIMINATION_UPDATE_B = 15;
    localparam BACK_SUBSTITUTION = 16;
    localparam BACK_SUB_SUM = 17;
    localparam BACK_SUB_PREP_DIV = 18;
    localparam BACK_SUB_DIV = 19;
    localparam BACK_SUB_APPLY = 20;
    localparam BACK_SUB_DECREMENT = 21;
    localparam DONE_STATE = 22;
    
    reg [4:0] state;
    reg [5:0] input_cnt;
    reg [5:0] i, j, k; // General counters
    
    // Storage
    reg signed [63:0] A [0:MAX_HOLES-1][0:MAX_HOLES-1];
    reg signed [63:0] b [0:MAX_HOLES-1];
    reg signed [63:0] X [0:MAX_HOLES-1]; // Solution
    reg [31:0] payouts [0:MAX_HOLES-1];
    reg [31:0] probs [0:4];
    
    // Division Engine
    reg div_start;
    reg div_done;
    reg [63:0] div_dividend;
    reg [63:0] div_divisor;
    reg signed [63:0] div_quotient;
    reg [5:0] div_cycles;
    
    // Division Combinational Logic (Shift subtract)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cycles <= 0;
            div_quotient <= 0;
            div_done <= 1'b0;
        end else begin
            if (div_start) begin
                div_done <= 1'b0;
                div_quotient <= 0;
                div_cycles <= 32; // 32 iterations for 32-bit result
                // Handle divide by zero
                if (div_divisor == 0) div_cycles <= 0;
            end else if (div_cycles > 0) begin
                // Shift dividend and quotient
                // If dividend >= divisor, set quotient bit and subtract
                // We need to handle large numbers.
                // Let's implement the basic shift-add algorithm.
                // To keep it 1-cycle per bit:
                // Actually, this 'always' block is sequential, so we do one step per cycle.
                // But we need to check if div_cycles is decremented here or in state machine.
                // We will decrement here.
                
                div_dividend <= div_dividend << 1;
                div_quotient <= div_quotient << 1;
                
                // Check if we can subtract
                if (div_dividend >= div_divisor) begin
                    div_quotient <= (div_quotient << 1) | 1;
                    div_dividend <= div_dividend - div_divisor;
                end
                div_cycles <= div_cycles - 1;
            end else begin
                div_done <= 1'b1;
            end
        end
    end
    
    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            ready_for_input <= 0;
            div_start <= 0;
            input_cnt <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    input_cnt <= 0;
                    if (start && num_holes > 0 && num_holes <= MAX_HOLES) begin
                        state <= LOAD_PAYOUTS;
                        ready_for_input <= 1;
                    end
                end
                
                LOAD_PAYOUTS: begin
                    if (ready_for_input) begin
                        ready_for_input <= 0;
                        payouts[input_cnt] <= payouts_in;
                        input_cnt <= input_cnt + 1;
                    end else begin
                        ready_for_input <= 1;
                        if (input_cnt == num_holes) begin
                            state <= LOAD_PROBS;
                            input_cnt <= 0;
                        end
                    end
                end
                
                LOAD_PROBS: begin
                    if (ready_for_input) begin
                        ready_for_input <= 0;
                        probs[input_cnt] <= probs_in;
                        input_cnt <= input_cnt + 1;
                    end else begin
                        ready_for_input <= 1;
                        if (input_cnt == 5) begin // 5 probs: p0-p4
                            state <= BUILD_MATRIX;
                            ready_for_input <= 0;
                            input_cnt <= 0; // Use for hole index
                            i <= 0;
                        end
                    end
                end
                
                BUILD_MATRIX: begin
                    // Initialize A[i][i] and b[i]
                    if (i < num_holes) begin
                        A[i][i] <= $signed({32'h0, Q16_16_ONE}) - $signed({32'h0, probs[4]});
                        b[i] <= $signed({32'h0, payouts[i]});
                        // Clear other entries for this row to 0
                        for (integer c = 0; c < MAX_HOLES; c = c + 1) begin
                            if (c != i) A[i][c] <= 64'sd0;
                        end
                        state <= CALC_ROW_NEIGHBORS;
                        j <= 0; // Neighbor counter
                    end else begin
                        state <= ELIMINATION_START;
                    end
                end
                
                CALC_ROW_NEIGHBORS: begin
                    // Determine neighbors for hole i
                    // Find row and col of hole i
                    // Row 0: size 1, Row 1: size 2, Row 2: size 3, Row 3: size 4...
                    // Hole 0: (0,0)
                    // Hole 1: (1,0), Hole 2: (1,1)
                    // Hole 3: (2,0), Hole 4: (2,1), Hole 5: (2,2)
                    // Hole 6: (3,0), Hole 7: (3,1), Hole 8: (3,2), Hole 9: (3,3)
                    
                    reg [3:0] r, c;
                    // Combinational logic to find r, c
                    if (i < 1) begin r = 0; c = 0; end
                    else if (i < 3) begin r = 1; c = i - 1; end
                    else if (i < 6) begin r = 2; c = i - 3; end
                    else begin r = 3; c = i - 6; end
                    
                    case (j)
                        0: begin // Left Parent (r-1, c-1)
                            if (c > 0 && r > 0) begin
                                A[i][(r-1)*(r)/2 + (c-1)] <= - $signed({32'h0, probs[0]});
                            end
                            j <= j + 1;
                        end
                        1: begin // Right Parent (r-1, c)
                            if (c < r && r > 0) begin
                                A[i][(r-1)*(r)/2 + (c)] <= - $signed({32'h0, probs[1]});
                            end
                            j <= j + 1;
                        end
                        2: begin // Left Child (r+1, c)
                            if (r < 3 && (i + r + 1) < num_holes) begin // Check bounds roughly
                                A[i][(r+1)*(r+2)/2 + (c)] <= - $signed({32'h0, probs[2]});
                            end
                            j <= j + 1;
                        end
                        3: begin // Right Child (r+1, c+1)
                            if (r < 3 && (i + r + 2) < num_holes) begin
                                A[i][(r+1)*(r+2)/2 + (c+1)] <= - $signed({32'h0, probs[3]});
                            end
                            // Last neighbor check
                            // Done with this row
                            i <= i + 1;
                            if (i + 1 == num_holes) state <= BUILD_MATRIX; // Next row in BUILD_MATRIX
                            else state <= BUILD_MATRIX;
                            j <= 0;
                        end
                        default: begin
                            i <= i + 1;
                            state <= BUILD_MATRIX;
                        end
                    endcase
                end
                
                ELIMINATION_START: begin
                    i <= 0;
                    state <= ELIMINATION_OUTER;
                end
                
                ELIMINATION_OUTER: begin
                    if (i < num_holes - 1) begin
                        // Find pivot in column i
                        j <= i + 1;
                        max_val <= A[i][i];
                        pivot_row <= i;
                        state <= ELIMINATION_PIVOT_FIND;
                    end else begin
                        state <= BACK_SUBSTITUTION;
                        row_idx <= num_holes - 1;
                    end
                end
                
                ELIMINATION_PIVOT_FIND: begin
                    if (j < num_holes) begin
                        if ($signed(A[j][i]) > $signed(max_val)) begin
                            max_val <= A[j][i];
                            pivot_row <= j;
                        end
                        j <= j + 1;
                    end else begin
                        // Swap if needed
                        if (pivot_row != i) begin
                            // We need to swap row i and pivot_row
                            // We will swap element by element in ELIMINATION_SWAP state
                            // Or use a counter k for columns
                            k <= 0;
                            state <= ELIMINATION_SWAP;
                        end else begin
                            state <= ELIMINATION_FACTOR;
                        end
                    end
                end
                
                ELIMINATION_SWAP: begin
                    // Swap A[i][k] <-> A[pivot_row][k]
                    // Swap b[i] <-> b[pivot_row]
                    if (k < num_holes) begin
                        A[i][k] <= A[pivot_row][k];
                        A[pivot_row][k] <= A[i][k];
                        k <= k + 1;
                    end else begin
                        // Swap b
                        b[i] <= b[pivot_row];
                        b[pivot_row] <= b[i];
                        state <= ELIMINATION_FACTOR;
                    end
                end
                
                ELIMINATION_FACTOR: begin
                    // Factor = A[j][i] / A[i][i]
                    // Loop through rows j = i+1 to n-1
                    if (j < num_holes) begin
                        // Division: (A[j][i] << 16) / A[i][i]
                        div_dividend <= {A[j][i][63:32], 16'h0000};
                        div_divisor <= {A[i][i][63:32], 16'h0000};
                        // Start division
                        // Since we need sequential division, we enter a WAIT state
                        // We will manage division progress in WAIT state
                        div_cycles <= 32;
                        div_quotient <= 0;
                        // Check for 0 divisor just in case
                        if (A[i][i] == 0) begin
                             // Singular matrix, just skip or set factor to 0
                             factor <= 0;
                             k <= 0;
                             state <= ELIMINATION_UPDATE;
                        end else begin
                             input_cnt <= 0; // mode 0
                             state <= DIV_START;
                        end
                    end else begin
                        i <= i + 1;
                        state <= ELIMINATION_OUTER;
                    end
                end
                
                DIV_START: begin
                    div_start <= 1'b1;
                    state <= WAIT_DIV;
                end
                
                WAIT_DIV: begin
                    if (div_done) begin
                        if (input_cnt == 0) state <= ELIMINATION_FACTOR_STORE;
                        else state <= BACK_SUB_APPLY;
                    end
                end
                
                ELIMINATION_FACTOR_STORE: begin
                    factor <= div_quotient;
                    k <= 0; // Column index for update
                    state <= ELIMINATION_UPDATE;
                end
                
                ELIMINATION_UPDATE: begin
                    // A[j][k] = A[j][k] - factor * A[i][k]
                    // We need to update row j (index stored in j from ELIMINATION_FACTOR start)
                    // Update columns k from i to num_holes-1 (others are 0 or already handled)
                    // Also update b[j]
                    
                    if (k < num_holes) begin
                        // Mult: factor * A[i][k]
                        temp_val <= ($signed(factor) * $signed(A[i][k])) >>> 16;
                        state <= ELIMINATION_UPDATE_APPLY;
                    end else begin
                        // Update b[j] - factor * b[i]
                        temp_val <= ($signed(factor) * $signed(b[i])) >>> 16;
                        state <= ELIMINATION_UPDATE_B;
                    end
                end
                
                ELIMINATION_UPDATE_APPLY: begin
                    A[j][k] <= $signed(A[j][k]) - temp_val;
                    k <= k + 1;
                    state <= ELIMINATION_UPDATE;
                end
                
                ELIMINATION_UPDATE_B: begin
                    b[j] <= $signed(b[j]) - temp_val;
                    j <= j + 1; // Next row to eliminate
                    state <= ELIMINATION_FACTOR; // Loop back to get factor for next row
                end
                
                BACK_SUBSTITUTION: begin
                    if (row_idx >= 0) begin
                        // Compute sum of A[row_idx][k] * X[k] for k > row_idx
                        sum_val <= 0;
                        k <= row_idx + 1;
                        if (row_idx == num_holes - 1) state <= BACK_SUB_PREP_DIV; // No sum needed for last row
                        else state <= BACK_SUB_SUM;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                BACK_SUB_SUM: begin
                    if (k < num_holes) begin
                        temp_val <= ($signed(A[row_idx][k]) * $signed(X[k])) >>> 16;
                        state <= BACK_SUB_ADD;
                    end else begin
                        // Subtract sum from b[row_idx] and divide
                        // Prepare dividend: (b - sum) << 16
                        // b is already Q16.16, X is Q16.16.
                        // b - sum is Q16.16.
                        // We need b[row_idx] - sum_val first.
                        b[row_idx] <= b[row_idx] - sum_val;
                        state <= BACK_SUB_DIV;
                    end
                end
                
                BACK_SUB_ADD: begin
                    sum_val <= sum_val + temp_val;
                    k <= k + 1;
                    state <= BACK_SUB_SUM;
                end
                
                BACK_SUB_PREP_DIV: begin
                    b[row_idx] <= b[row_idx] - sum_val;
                    state <= BACK_SUB_DIV;
                end
                
                BACK_SUB_DIV: begin
                    // Divide (b[row_idx] - sum) / A[row_idx][row_idx]
                    // Note: in BACK_SUB_SUM, we updated b[row_idx] if we went through sum loop.
                    // If we skipped sum loop (last row), b[row_idx] is original.
                    // Start Division
                    div_dividend <= {b[row_idx][63:32], 16'h0000};
                    div_divisor <= {A[row_idx][row_idx][63:32], 16'h0000};
                    div_cycles <= 32;
                    div_quotient <= 0;
                    if (A[row_idx][row_idx] == 0) begin
                        X[row_idx] <= 0;
                        state <= BACK_SUB_DECREMENT;
                    end else begin
                        input_cnt <= 1; // mode 1
                        state <= DIV_START;
                    end
                end
                
                BACK_SUB_APPLY: begin
                    X[row_idx] <= div_quotient;
                    state <= BACK_SUB_DECREMENT;
                end
                
                BACK_SUB_DECREMENT: begin
                    row_idx <= row_idx - 1;
                    state <= BACK_SUBSTITUTION;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule