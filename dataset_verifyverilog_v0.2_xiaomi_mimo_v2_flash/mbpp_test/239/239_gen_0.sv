module sequence_counter(
    input clk,
    input rst_n,
    input start,
    input [4:0] m,
    input [2:0] n,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE_COL = 3'b010;
    localparam UPDATE = 3'b011;
    localparam STORE = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state and counters
    reg [2:0] state;
    reg [4:0] row_i; // 0 to 16
    reg [2:0] col_j; // 1 to 4
    reg [15:0] T [16:0][4:0]; // DP table: T[i][j]
    
    // Temporary storage for intermediate values
    reg [15:0] val_T_im1_j;    // T[i-1][j]
    reg [15:0] val_T_iHalf_jm1; // T[i//2][j-1]
    reg [15:0] computed_sum;    // Sum of values for UPDATE

    // Combinational helper for i/2 (integer division)
    wire [4:0] i_half;
    assign i_half = row_i >> 1; // Right shift by 1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            row_i <= 5'b0;
            col_j <= 3'b0;
            // Clear T matrix (optional in reset, but good practice)
            // In hardware, we rely on state logic to write valid data before reading.
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Reset counters
                    row_i <= 5'b0;
                    col_j <= 3'b1; // Start with j=1
                    // Initialize base cases for j=1
                    // T[i][1] = i. We handle this in the loop logic for j=1.
                    // We start by computing T[0][1] if needed, or start loop at i=1.
                    // The problem states T[i][1] = i. So for i=0, T[0][1]=0. 
                    // We will start loop at i=1 for j=1.
                    row_i <= 5'b1;
                    state <= COMPUTE_COL;
                end

                COMPUTE_COL: begin
                    // Load T[i-1][j] for current i and j
                    // For j=1, base case T[i][1] = i is handled directly in UPDATE logic.
                    // But we need T[i-1][j] for the formula T[i][j] = T[i-1][j] + T[i/2][j-1].
                    // If j=1, T[i/2][0] is 0. T[i-1][1] is (i-1).
                    // The problem says T[i][1] = i. 
                    // So if we are in COMPUTE_COL for j=1, we might skip loading T[i-1][j] 
                    // if we just use the formula T[i][j] = T[i-1][j] + ...
                    // Let's strictly follow the formula:
                    // T[i][j] = T[i-1][j] + T[i//2][j-1].
                    // For j=1: T[i][1] = T[i-1][1] + T[i//2][0].
                    // T[0][1] = 0. 
                    // T[1][1] = T[0][1] + T[0][0] = 0 + 0 = 0. -> This contradicts "T[i][1] = i".
                    // Wait, the prompt says "Base cases: T[i][1] = i".
                    // This implies the recurrence T[i][j] = ... does not apply for j=1.
                    // It is a base case.
                    // However, the prompt also says "At each state, accumulate values and update T[row_i][col_j]".
                    // And "When computing T[i][j]: need T[i-1][j] and T[i//2][j-1]".
                    
                    // Let's interpret: The recurrence defines the general step.
                    // Base cases override this.
                    // We will handle j=1 specifically.
                    
                    // Load T[i-1][j] (needed for j>1 usually, but let's load it always if valid index)
                    if (row_i > 0) begin
                        val_T_im1_j <= T[row_i - 1][col_j];
                    end else begin
                        val_T_im1_j <= 16'b0;
                    end
                    
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Compute T[i//2][j-1]
                    // And accumulate
                    
                    if (col_j == 3'd1) begin
                        // Base case: T[i][1] = i
                        computed_sum <= row_i; // i is row_i
                    end else begin
                        // Recurrence: T[i][j] = T[i-1][j] + T[i//2][j-1]
                        // val_T_im1_j is already loaded (T[i-1][j])
                        // We need T[i/2][j-1]
                        
                        // Check if i/2 is valid (>=0) and j-1 >= 1 (always true here)
                        if (i_half > 0 && col_j > 1) begin
                            // Note: col_j is current, so j-1 = col_j - 1 (which is 1-based index in code?)
                            // My register col_j runs 1 to n.
                            val_T_iHalf_jm1 <= T[i_half][col_j - 1];
                            computed_sum <= val_T_im1_j + T[i_half][col_j - 1];
                        end else begin
                            // i_half is 0. T[0][j] is 0 for j >= 1.
                            computed_sum <= val_T_im1_j;
                        end
                    end
                    
                    state <= STORE;
                end

                STORE: begin
                    // Write T[i][j] = computed_sum
                    T[row_i][col_j] <= computed_sum;
                    
                    // Increment row_i
                    if (row_i < m) begin
                        row_i <= row_i + 1;
                        state <= COMPUTE_COL; // Loop back for next row
                    end else begin
                        // Row done for this column
                        if (col_j < n) begin
                            col_j <= col_j + 1;
                            row_i <= 5'b1; // Reset row for next column (T[0][j] is 0)
                            state <= COMPUTE_COL;
                        end else begin
                            // All columns done
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    result <= T[m][n];
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to return to IDLE
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
