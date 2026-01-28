module binomial_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_I = 3'd2;
    localparam [2:0] LOOP_J = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] C_reg [0:7]; // Array for binomial coefficients
    reg [3:0] i_reg;         // Outer loop counter
    reg [3:0] j_reg;         // Inner loop counter
    reg [15:0] result_reg;
    reg done_reg;
    reg [3:0] n_reg;         // Stored n value
    reg [3:0] n_minus_1;     // Stored n-1
    reg [3:0] two_n;         // Stored 2*n
    reg [3:0] min_j_limit;   // Min(i, n-1)
    reg [9:0] cycle_count;   // Safety counter (max 512)

    // Integer for for-loop initialization
    integer init_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            n_reg <= 4'd0;
            n_minus_1 <= 4'd0;
            two_n <= 4'd0;
            min_j_limit <= 4'd0;
            cycle_count <= 10'd0;
            result <= 16'd0;
            done <= 1'b0;
            // Initialize array to 0
            for (init_idx = 0; init_idx < 8; init_idx = init_idx + 1) begin
                C_reg[init_idx] <= 16'd0;
            end
        end else begin
            // Default outputs
            done <= 1'b0;
            result <= result_reg;
            
            // State transition
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    result_reg <= 16'd0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        n_reg <= n;
                        n_minus_1 <= (n > 0) ? (n - 1) : 4'd0;
                        two_n <= n << 1; // Multiply by 2
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize C[0] = 1, rest 0
                    for (init_idx = 0; init_idx < 8; init_idx = init_idx + 1) begin
                        if (init_idx == 0)
                            C_reg[0] <= 16'd1;
                        else
                            C_reg[init_idx] <= 16'd0;
                    end
                    i_reg <= 4'd1; // Start loop at i=1
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    // Check loop condition: i <= 2*n
                    if (i_reg <= two_n) begin
                        // Calculate min(i, n-1) for inner loop limit
                        if (i_reg < n_minus_1)
                            min_j_limit <= i_reg;
                        else
                            min_j_limit <= n_minus_1;
                        
                        j_reg <= min_j_limit;
                        
                        // If min_j_limit > 0, enter inner loop
                        if (min_j_limit > 4'd0)
                            state <= LOOP_J;
                        else
                            state <= INCREMENT_I;
                    end else begin
                        state <= DONE;
                    end
                end

                LOOP_J: begin
                    // Check inner loop: j >= 1
                    if (j_reg >= 4'd1) begin
                        state <= UPDATE;
                    end else begin
                        // Inner loop done
                        state <= INCREMENT_I;
                    end
                end

                UPDATE: begin
                    // C[j] = C[j] + C[j-1]
                    C_reg[j_reg] <= C_reg[j_reg] + C_reg[j_reg - 1];
                    j_reg <= j_reg - 4'd1;
                    cycle_count <= cycle_count + 10'd1;
                    state <= LOOP_J;
                end

                INCREMENT_I: begin
                    i_reg <= i_reg + 4'd1;
                    cycle_count <= cycle_count + 10'd1;
                    state <= LOOP_I;
                end

                DONE: begin
                    // Final result: C[n-1]
                    if (n_minus_1 < 8)
                        result_reg <= C_reg[n_minus_1];
                    else
                        result_reg <= 16'd0; // Safety fallback
                    
                    done_reg <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Safety timeout
            if (cycle_count >= 10'd512 && state != IDLE) begin
                state <= IDLE;
            end
        end
    end

endmodule