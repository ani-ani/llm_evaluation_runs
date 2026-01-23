module random_pictures (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] m,
    output reg [31:0] result,
    output reg done
);

// Parameters
parameter MOD = 1000000007;

// States
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] DONE = 2'd2;

// Registers
reg [1:0] state;
reg [7:0] i;
reg [7:0] max_idx;
reg [7:0] n_minus_1;
reg [7:0] m_minus_1;
reg [31:0] curr;
reg [31:0] next;
reg [31:0] val_n;
reg [31:0] val_m;

// Combinational signals for first cycle
wire [7:0] n_minus_1_comb = (n > 0) ? n - 1 : 0;
wire [7:0] m_minus_1_comb = (m > 0) ? m - 1 : 0;
wire [7:0] max_idx_comb = (n_minus_1_comb > m_minus_1_comb) ? n_minus_1_comb : m_minus_1_comb;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        i <= 8'd0;
        curr <= 32'd0;
        next <= 32'd0;
        val_n <= 32'd0;
        val_m <= 32'd0;
        max_idx <= 8'd0;
        n_minus_1 <= 8'd0;
        m_minus_1 <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Initialize registers based on inputs
                    n_minus_1 <= n_minus_1_comb;
                    m_minus_1 <= m_minus_1_comb;
                    max_idx <= max_idx_comb;
                    i <= 8'd0;
                    curr <= 32'd1; // F(0)
                    next <= 32'd2; // F(1)
                    // Capture F(0) if needed
                    val_n <= (n_minus_1_comb == 0) ? 32'd1 : 32'd0;
                    val_m <= (m_minus_1_comb == 0) ? 32'd1 : 32'd0;
                    // Transition
                    if (max_idx_comb == 0)
                        state <= DONE;
                    else
                        state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Capture current Fibonacci value if needed
                if (i == n_minus_1 && val_n == 0)
                    val_n <= curr;
                if (i == m_minus_1 && val_m == 0)
                    val_m <= curr;
                
                // Check if done
                if (i == max_idx) begin
                    state <= DONE;
                end else begin
                    // Update for next index
                    i <= i + 8'd1;
                    curr <= next;
                    // Compute next Fibonacci number modulo MOD
                    if (curr + next >= MOD)
                        next <= curr + next - MOD;
                    else
                        next <= curr + next;
                end
            end
            
            DONE: begin
                // Compute result: 2 * (val_n + val_m - 1) mod MOD
                // First compute sum - 1
                reg [31:0] sum;
                if (val_n + val_m >= 1) begin
                    if (val_n + val_m - 1 >= MOD)
                        sum <= val_n + val_m - 1 - MOD;
                    else
                        sum <= val_n + val_m - 1;
                end else begin
                    sum <= MOD - 1; // Should not happen for valid inputs
                end
                // Then multiply by 2
                if (sum >= (MOD >> 1)) // sum >= MOD/2
                    result <= (sum << 1) - MOD;
                else
                    result <= sum << 1;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule