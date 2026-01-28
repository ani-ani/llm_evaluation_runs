module fibonacci_substring_search(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] n,
    input wire [19:0] a,
    input wire [19:0] d,
    output reg [63:0] b,
    output reg [63:0] e,
    output reg valid
);

// Constants
localparam [33:0] N = 34'd12000000000;          // 12 * 10^9
localparam [28:0] MULTIPLIER = 29'd368131125;   // Multiplier for modular reduction
localparam [29:0] MOD = 30'd1000000000;         // 10^9

// State definitions
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] COMPUTE_U  = 3'd1;
localparam [2:0] COMPUTE_V  = 3'd2;
localparam [2:0] COMPUTE_B  = 3'd3;
localparam [2:0] COMPUTE_E  = 3'd4;
localparam [2:0] FINISH     = 3'd5;

// State registers
reg [2:0] state, next_state;

// Intermediate computation registers
reg [63:0] mult_result;      // Temporary for multiplication
reg [63:0] mod_result;       // Temporary for modulo
reg [63:0] u_val, v_val;     // Store computed u and v
reg [5:0] cycle_count;       // Cycle counter for timeout (0-63)
localparam [5:0] MAX_CYCLES = 6'd50; // Safe limit for computations

// Control signals
reg compute_done;
reg [2:0] compute_step;      // Step counter for iterative multiplication

// Always block for sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        b <= 64'd0;
        e <= 64'd0;
        valid <= 1'b0;
        mult_result <= 64'd0;
        mod_result <= 64'd0;
        u_val <= 64'd0;
        v_val <= 64'd0;
        cycle_count <= 6'd0;
        compute_step <= 3'd0;
        compute_done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                valid <= 1'b0;
                cycle_count <= 6'd0;
                compute_step <= 3'd0;
                if (start) begin
                    state <= COMPUTE_U;
                end
            end
            
            COMPUTE_U: begin
                cycle_count <= cycle_count + 6'd1;
                case (compute_step)
                    3'd0: begin
                        // Step 0: Start multiplication: u = (MULTIPLIER * a) % MOD
                        // Since a <= 10^6 and MULTIPLIER ~ 3.68e8, result fits in 64 bits
                        mult_result <= {35'd0, a} * {35'd0, MULTIPLIER}; // a * MULTIPLIER
                        compute_step <= 3'd1;
                    end
                    3'd1: begin
                        // Step 1: Perform modulo operation
                        // mod_result = mult_result % MOD
                        // Using built-in division
                        mod_result <= mult_result % {30'd0, MOD}; // mod 10^9
                        compute_step <= 3'd2;
                    end
                    3'd2: begin
                        // Step 2: Store u value
                        u_val <= mod_result;
                        compute_step <= 3'd0;
                        state <= COMPUTE_V;
                    end
                    default: begin
                        compute_step <= 3'd0;
                        state <= IDLE;
                    end
                endcase
            end
            
            COMPUTE_V: begin
                cycle_count <= cycle_count + 6'd1;
                case (compute_step)
                    3'd0: begin
                        // Step 0: Start multiplication: v = (MULTIPLIER * d) % MOD
                        mult_result <= {35'd0, d} * {35'd0, MULTIPLIER}; // d * MULTIPLIER
                        compute_step <= 3'd1;
                    end
                    3'd1: begin
                        // Step 1: Perform modulo operation
                        mod_result <= mult_result % {30'd0, MOD}; // mod 10^9
                        compute_step <= 3'd2;
                    end
                    3'd2: begin
                        // Step 2: Store v value
                        v_val <= mod_result;
                        compute_step <= 3'd0;
                        state <= COMPUTE_B;
                    end
                    default: begin
                        compute_step <= 3'd0;
                        state <= IDLE;
                    end
                endcase
            end
            
            COMPUTE_B: begin
                cycle_count <= cycle_count + 6'd1;
                case (compute_step)
                    3'd0: begin
                        // Step 0: Compute b = u_val * N
                        // u_val < 10^9, N = 12*10^9, so result < 12*10^18 < 2^64
                        mult_result <= u_val * N;
                        compute_step <= 3'd1;
                    end
                    3'd1: begin
                        // Step 1: Add 1 to get final b
                        b <= mult_result + 64'd1;
                        compute_step <= 3'd0;
                        state <= COMPUTE_E;
                    end
                    default: begin
                        compute_step <= 3'd0;
                        state <= IDLE;
                    end
                endcase
            end
            
            COMPUTE_E: begin
                cycle_count <= cycle_count + 6'd1;
                case (compute_step)
                    3'd0: begin
                        // Step 0: Compute e = v_val * N
                        mult_result <= v_val * N;
                        compute_step <= 3'd1;
                    end
                    3'd1: begin
                        // Step 1: Store final e
                        e <= mult_result;
                        compute_step <= 3'd0;
                        state <= FINISH;
                    end
                    default: begin
                        compute_step <= 3'd0;
                        state <= IDLE;
                    end
                endcase
            end
            
            FINISH: begin
                valid <= 1'b1; // Assert valid output
                state <= IDLE; // Return to idle
            end
            
            default: begin
                state <= IDLE;
                valid <= 1'b0;
            end
        endcase
        
        // Safety timeout: if computation takes too long, reset
        if (cycle_count >= MAX_CYCLES && (state == COMPUTE_U || state == COMPUTE_V || state == COMPUTE_B || state == COMPUTE_E)) begin
            state <= IDLE;
            valid <= 1'b0;
            cycle_count <= 6'd0;
        end
    end
end

endmodule