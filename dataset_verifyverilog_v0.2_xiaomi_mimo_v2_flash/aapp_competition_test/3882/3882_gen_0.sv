module sym_trans_count(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [29:0] result,
    output reg done
);

    // Parameters
    parameter MOD = 30'd1000000007;
    
    // State definition
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam ROW_LOOP = 3'b010;
    localparam COL_LOOP = 3'b011;
    localparam CALC = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state machine
    reg [2:0] current_state, next_state;
    
    // Registers for counters and indices
    reg [3:0] i; // Row index (0 to n)
    reg [3:0] j; // Column index (0 to n)
    reg [3:0] k; // Loop counter
    
    // Memory storage for A[i][j]
    // Max dimension 9x9 (0..8)
    reg [29:0] A [0:8][0:8];
    
    // Temporary registers for calculation
    reg [29:0] temp_sum;
    reg [29:0] val_1;
    reg [29:0] val_2;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                next_state = ROW_LOOP;
            end
            ROW_LOOP: begin
                if (i <= n)
                    next_state = COL_LOOP;
                else
                    next_state = DONE; // Should not happen, but safe fallback
            end
            COL_LOOP: begin
                if (j <= i) 
                    next_state = CALC;
                else 
                    next_state = ROW_LOOP;
            end
            CALC: begin
                next_state = COL_LOOP;
            end
            DONE: begin
                if (start) // Wait for start to go low to return to IDLE if needed, or stay here
                    next_state = DONE; 
                else
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 30'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    // Wait for start
                end
                
                INIT: begin
                    // Initialize A[0][0] = 1
                    A[0][0] <= 30'd1;
                    i <= 4'd1;
                end
                
                ROW_LOOP: begin
                    // Check if finished
                    if (i > n) begin
                        // Fall through to DONE is handled by state transition logic above, 
                        // but strictly we need to transition to DONE state here explicitly in logic
                        // However, the state transition block handles it. 
                        // Just ensuring we stay safe.
                    end else begin
                        // Prepare for row i
                        j <= 4'd0; // Start col loop
                    end
                end
                
                COL_LOOP: begin
                    // Check if column loop finished for current row i
                    if (j > i) begin
                        // Move to next row
                        i <= i + 1;
                    end else begin
                        // We are inside the loop, execution moves to CALC state
                    end
                end
                
                CALC: begin
                    if (j == 0) begin
                        // A[i][0] = A[i-1][i-1]
                        A[i][j] <= A[i-1][i-1];
                    end else begin
                        // A[i][j] = A[i][j-1] + A[i-1][j-1]
                        // Handled in next state or combinationally? 
                        // Since it's sequential, we can compute it here.
                        // We need values A[i][j-1] and A[i-1][j-1].
                        // Both are available in the register file.
                        A[i][j] <= (A[i][j-1] + A[i-1][j-1]) % MOD;
                    end
                    // Increment column index
                    j <= j + 1;
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Result is A[n][n-1]
                    if (n == 0) result <= A[0][0]; // Edge case handling if n=0 input allowed
                    else result <= A[n][n-1];
                end
                
                default: begin
                    // Reset values or do nothing
                end
            endcase
        end
    end

    // Override next_state for DONE transition from ROW_LOOP
    // The ROW_LOOP state transition logic above is a bit simplified.
    // Let's refine the state transitions in the always block for safety.
    // Actually, the state transition block handles the logic flow.
    // We just need to ensure when i > n, we go to DONE.
    // Re-writing the state transition block fully to be safe.
    
    // Corrected State Transition Logic override
    always @(*) begin
        case (current_state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = ROW_LOOP;
            ROW_LOOP: begin
                if (i > n) next_state = DONE;
                else next_state = COL_LOOP;
            end
            COL_LOOP: begin
                if (j > i) next_state = ROW_LOOP; // Go to next row
                else next_state = CALC;
            end
            CALC: next_state = COL_LOOP;
            DONE: next_state = start ? DONE : IDLE; // Wait for start to go low
            default: next_state = IDLE;
        endcase
    end

endmodule