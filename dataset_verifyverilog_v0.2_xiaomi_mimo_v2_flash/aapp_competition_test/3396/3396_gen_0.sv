module goat_rope_solver(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_posts,
    input [15:0] post_x [0:7],
    input [15:0] post_y [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 0;
    localparam INIT_PAIRS = 1;
    localparam COMPUTE_DIST = 2;
    localparam SQRT_ITER = 3;
    localparam FIND_MIN = 4;
    localparam DIVIDE = 5;
    localparam ROUND = 6;
    localparam DONE = 7;

    reg [2:0] state;
    
    // Pair tracking (8 posts max = 28 pairs)
    reg [2:0] i, j;
    reg [4:0] pair_count; // 0 to 27
    
    // Coordinate registers
    reg [15:0] px_i, py_i, px_j, py_j;
    
    // Intermediate calculation registers
    reg signed [16:0] dx, dy; // 17-bit signed for subtraction
    reg [31:0] dx2, dy2;      // 32-bit for squares
    reg [31:0] sum;           // dx2 + dy2
    reg [31:0] min_distance;  // Current minimum distance
    
    // Square root computation registers
    reg [31:0] sqrt_val;      // Value to compute sqrt of
    reg [31:0] sqrt_rem;      // Remainder
    reg [31:0] sqrt_root;     // Current sqrt result
    reg [31:0] sqrt_bit;      // Current bit to test
    reg [4:0] sqrt_iter;      // Iteration counter (max 32 for 32-bit)
    
    // Temporary storage for distance computation
    reg [31:0] current_distance;
    
    // Rounding temporary
    reg [31:0] pre_round;
    
    // Combinational helper signals
    wire [31:0] dx2_wire, dy2_wire;
    wire [31:0] sum_wire;
    
    // Multipliers for dx*dx and dy*dy (17-bit signed input, 32-bit result)
    // Using signed multiplication: extend to 17-bit signed, multiply, get 34-bit, take [31:0]
    wire signed [33:0] dx_sq_full = $signed({{17{dx[16]}}, dx}) * $signed({{17{dx[16]}}, dx});
    wire signed [33:0] dy_sq_full = $signed({{17{dy[16]}}, dy}) * $signed({{17{dy[16]}}, dy});
    
    assign dx2_wire = dx_sq_full[31:0];
    assign dy2_wire = dy_sq_full[31:0];
    assign sum_wire = dx2_wire + dy2_wire;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            pair_count <= 0;
            i <= 0;
            j <= 0;
            min_distance <= 32'hFFFFFFFF; // Max value
            sqrt_iter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && num_posts > 1) begin
                        state <= INIT_PAIRS;
                        pair_count <= 0;
                        i <= 0;
                        j <= 1;
                        min_distance <= 32'hFFFFFFFF;
                    end else if (start) begin
                        // Single post or invalid, just go to done
                        result <= 0;
                        done <= 1;
                        state <= DONE;
                    end
                end

                INIT_PAIRS: begin
                    // Load current pair coordinates
                    px_i <= post_x[i];
                    py_i <= post_y[i];
                    px_j <= post_x[j];
                    py_j <= post_y[j];
                    state <= COMPUTE_DIST;
                end

                COMPUTE_DIST: begin
                    // Compute dx and dy
                    dx <= {1'b0, px_i} - {1'b0, px_j};
                    dy <= {1'b0, py_i} - {1'b0, py_j};
                    
                    // Wait one cycle for multiplication result from wires
                    state <= SQRT_ITER;
                    
                    // Initialize square root for this sum
                    // Use results from combinational logic after one cycle delay
                    // Actually we need to register the sum first
                    sqrt_rem <= 32'h0;
                    sqrt_root <= 32'h0;
                    sqrt_bit <= 32'h80000000; // Start with bit 31
                    sqrt_iter <= 0;
                end

                SQRT_ITER: begin
                    // First iteration: compute dx2, dy2, sum and store
                    if (sqrt_iter == 0) begin
                        dx2 <= dx2_wire;
                        dy2 <= dy2_wire;
                        sum <= sum_wire;
                        sqrt_val <= sum_wire;
                        
                        // If sum is 0, distance is 0
                        if (sum_wire == 0) begin
                            current_distance <= 0;
                            state <= FIND_MIN;
                        end else begin
                            sqrt_rem <= sum_wire;
                            sqrt_root <= 32'h0;
                            sqrt_bit <= 32'h40000000; // Start with bit 30 for 32-bit sqrt
                            sqrt_iter <= 1;
                        end
                    end else begin
                        // Iterative square root algorithm
                        // if (rem >= (root | bit)) then subtract and set bit
                        if (sqrt_rem >= (sqrt_root | sqrt_bit)) begin
                            sqrt_rem <= sqrt_rem - (sqrt_root | sqrt_bit);
                            sqrt_root <= sqrt_root | sqrt_bit;
                        end
                        sqrt_bit <= sqrt_bit >> 2;
                        sqrt_iter <= sqrt_iter + 1;
                        
                        // Terminate after enough iterations (16 iterations for 32-bit result)
                        if (sqrt_iter >= 16) begin
                            // Need one more shift in last iteration
                            if (sqrt_bit < 2) begin
                                current_distance <= sqrt_root;
                                state <= FIND_MIN;
                            end
                        end
                    end
                end

                FIND_MIN: begin
                    // Update min_distance if current is smaller
                    if (current_distance < min_distance) begin
                        min_distance <= current_distance;
                    end
                    
                    // Move to next pair
                    // Increment j first
                    if (j < (num_posts - 1)) begin
                        j <= j + 1;
                        state <= INIT_PAIRS;
                    end else begin
                        // Increment i and reset j
                        if (i < (num_posts - 2)) begin
                            i <= i + 1;
                            j <= i + 2;
                            state <= INIT_PAIRS;
                        end else begin
                            // All pairs processed
                            state <= DIVIDE;
                        end
                    end
                end

                DIVIDE: begin
                    // Divide by 2 (right shift by 1)
                    // Also preserves the fractional part
                    result <= min_distance >> 1;
                    state <= ROUND;
                end

                ROUND: begin
                    // Round to nearest
                    // Check bit 15 of fractional part (since Q16.16)
                    // Result is currently shifted, so the rounding bit is bit 0 of the stored value
                    // Wait, let me reconsider:
                    // min_distance is Q16.16 with 32 bits
                    // min_distance / 2 = min_distance >> 1
                    // The result has 32 bits. For rounding in Q16.16:
                    // We need to check if the LSB (bit 0) of the result should cause rounding up.
                    // Actually the rounding is to nearest Q16.16 value.
                    // After division by 2, bit 0 is the fractional remainder.
                    pre_round <= result;
                    if (result[0] == 1) begin
                        result <= result + 1;
                    end else begin
                        result <= result;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
