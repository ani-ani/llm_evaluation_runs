module fair_nut_strings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_s,
    input wire [7:0] char_t,
    input wire [31:0] k,
    output reg [31:0] result,
    output reg done,
    output reg [7:0] char_idx
);

    // Constants
    localparam MAX_CHARS = 100;
    localparam COUNTER_WIDTH = 32;

    // State definitions
    localparam IDLE = 3'b000;
    localparam READ_CHAR = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam ACCUMULATE = 3'b011;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [7:0] n_cnt;           // Counts 0 to n-1 (n=100)
    reg [31:0] cur_count;      // Current number of possible prefixes
    reg [31:0] total_sum;      // Accumulated sum
    reg [31:0] temp_calc;      // Temp register for calculation
    reg [31:0] k_reg;          // Registered k
    
    // Wires for arithmetic to ensure no overflow in simulation, though logic handles saturation
    wire [63:0] calc_sum;
    wire [63:0] calc_mul;

    // Arithmetic calculations (pre-calculated for combinational logic in compute state)
    // Logic: cur_count * 2 + 1
    assign calc_mul = {32'b0, cur_count} * 2;
    assign calc_sum = calc_mul + 1;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 8'b0;
            result <= 32'b0;
            done <= 1'b0;
            cur_count <= 32'b0;
            total_sum <= 32'b0;
            temp_calc <= 32'b0;
            k_reg <= 32'b0;
            n_cnt <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ_CHAR;
                        // Reset accumulators
                        result <= 32'b0;
                        total_sum <= 32'b0;
                        // Per spec: cur_count reset to 1 at start
                        cur_count <= 32'h0000_0001;
                        char_idx <= 8'b0;
                        n_cnt <= 8'b0;
                        k_reg <= k; // Register k for consistent comparison
                    end
                end

                READ_CHAR: begin
                    // Inputs char_s and char_t are valid here.
                    // Move to compute to perform logic operations.
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Logic: 
                    // if s[i] == t[i]: cur_count = cur_count (no change)
                    // else: cur_count = (cur_count * 2) + 1
                    // Cap at k_reg
                    
                    if (char_s != char_t) begin
                        // Use truncated result if > 32 bits, logic implies wrapping or saturation
                        if (calc_sum[63:32] != 0 || calc_sum[31:0] > k_reg) begin
                            cur_count <= k_reg;
                        end else begin
                            cur_count <= calc_sum[31:0];
                        end
                    end else begin
                        // Equality: Check if current count is already > k (shouldn't happen if logic holds, but safety)
                        if (cur_count > k_reg) begin
                            cur_count <= k_reg;
                        end
                        // else stays same
                    end
                    state <= ACCUMULATE;
                end

                ACCUMULATE: begin
                    // total_sum += cur_count
                    // Check if total_sum would overflow k (cap final result if requested, 
                    // but spec says "count exceeds k, set cur_count = k", implies result sums cur_count).
                    // Assuming result saturates at k or just sums up.
                    // Spec 7: "If the count exceeds k, it saturates at k". This applies to cur_count.
                    // Spec 8: "result is the sum of valid prefix counts".
                    
                    if (total_sum + cur_count > k_reg) begin
                        result <= k_reg;
                    end else begin
                        result <= total_sum + cur_count;
                    end
                    
                    // Update total_sum for next iteration logic if needed (or just use result)
                    total_sum <= (total_sum + cur_count > k_reg) ? k_reg : (total_sum + cur_count);
                    
                    // Increment index and counter
                    if (n_cnt == 99) begin // 0 to 99 is 100 cycles (n=100)
                        state <= DONE;
                        char_idx <= char_idx; // Keep index at n-1 or wrap? Spec says 0 to n-1.
                        done <= 1'b1;
                    end else begin
                        state <= READ_CHAR;
                        char_idx <= char_idx + 1;
                        n_cnt <= n_cnt + 1;
                    end
                end

                DONE: begin
                    // Stay in done state until start goes low (implied) or reset
                    // Keep done high.
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule