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

// State definitions
localparam [2:0] IDLE    = 3'b001;
localparam [2:0] COMPUTE = 3'b010;
localparam [2:0] DONE    = 3'b100;

// Registers
reg [2:0] state;
reg [2:0] next_state;
reg [7:0] i;
reg [7:0] max_idx;
reg [7:0] n_minus_1_reg;
reg [7:0] m_minus_1_reg;
reg [31:0] curr;
reg [31:0] next_val;
reg [31:0] val_n;
reg [31:0] val_m;
reg [31:0] sum_reg;
reg computation_done;
reg [7:0] n_minus_1_comb;
reg [7:0] m_minus_1_comb;
reg [7:0] max_idx_comb;

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

// Combinational logic for initial calculations
always @(*) begin
    n_minus_1_comb = (n > 8'd0) ? n - 8'd1 : 8'd0;
    m_minus_1_comb = (m > 8'd0) ? m - 8'd1 : 8'd0;
    if (n_minus_1_comb > m_minus_1_comb)
        max_idx_comb = n_minus_1_comb;
    else
        max_idx_comb = m_minus_1_comb;
end

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        i <= 8'd0;
        curr <= 32'd0;
        next_val <= 32'd0;
        val_n <= 32'd0;
        val_m <= 32'd0;
        max_idx <= 8'd0;
        n_minus_1_reg <= 8'd0;
        m_minus_1_reg <= 8'd0;
        sum_reg <= 32'd0;
        computation_done <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    // Initialize registers
                    n_minus_1_reg <= n_minus_1_comb;
                    m_minus_1_reg <= m_minus_1_comb;
                    max_idx <= max_idx_comb;
                    i <= 8'd0;
                    curr <= 32'd1;  // F(0)
                    next_val <= 32'd2;  // F(1)
                    // Capture F(0) if needed
                    if (n_minus_1_comb == 8'd0)
                        val_n <= 32'd1;
                    else
                        val_n <= 32'd0;
                    if (m_minus_1_comb == 8'd0)
                        val_m <= 32'd1;
                    else
                        val_m <= 32'd0;
                    computation_done <= 1'b0;
                    sum_reg <= 32'd0;
                    
                    if (max_idx_comb == 8'd0) begin
                        state <= DONE;
                    end else begin
                        state <= COMPUTE;
                    end
                end
            end
            
            COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Capture current Fibonacci value if needed
                if (i == n_minus_1_reg && val_n == 32'd0)
                    val_n <= curr;
                if (i == m_minus_1_reg && val_m == 32'd0)
                    val_m <= curr;
                
                // Check if done
                if (i == max_idx || cycle_count >= MAX_CYCLES) begin
                    state <= DONE;
                end else begin
                    // Update for next index
                    i <= i + 8'd1;
                    curr <= next_val;
                    // Compute next Fibonacci number modulo MOD
                    if (curr + next_val >= MOD)
                        next_val <= curr + next_val - MOD;
                    else
                        next_val <= curr + next_val;
                end
            end
            
            DONE: begin
                // Compute result: 2 * (val_n + val_m - 1) mod MOD
                // First compute sum - 1
                if (val_n + val_m >= 32'd1) begin
                    if (val_n + val_m - 32'd1 >= MOD)
                        sum_reg <= val_n + val_m - 32'd1 - MOD;
                    else
                        sum_reg <= val_n + val_m - 32'd1;
                end else begin
                    sum_reg <= MOD - 32'd1;  // Should not happen for valid inputs
                end
                
                // Then multiply by 2
                if (sum_reg >= (MOD >> 1))  // sum >= MOD/2
                    result <= (sum_reg << 1) - MOD;
                else
                    result <= sum_reg << 1;
                
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule