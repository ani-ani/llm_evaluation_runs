module min_days_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Requirements (0-1023)
    input wire [9:0] p,
    input wire [9:0] q,
    
    // Number of projects (1-16)
    input wire [3:0] n,
    
    // Project arrays - 16 elements max, each 8-bit
    // Access pattern: arr[i] for i in 0-15
    input wire [7:0] a [0:15],
    input wire [7:0] b [0:15],
    
    // Result in Q12.12 format (12 integer + 12 fractional bits)
    output reg [23:0] result,
    output reg done
);

// Internal states
localparam [2:0] IDLE          = 3'd0;
localparam [2:0] LOAD          = 3'd1;
localparam [2:0] COMPUTE       = 3'd2;
localparam [2:0] DIVIDE        = 3'd3;
localparam [2:0] UPDATE_BEST   = 3'd4;
localparam [2:0] NEXT_PAIR     = 3'd5;
localparam [2:0] COMPLETE      = 3'd6;

reg [2:0] state;
reg [3:0] idx_i, idx_j;  // Project indices
reg [23:0] best_result;   // Best result so far (Q12.12) - max value initially
reg [23:0] temp_result;   // Temporary calculation
reg [23:0] temp_result2;  // Second temporary
reg [23:0] current_max;   // Max of two divisions

// Division state
reg [1:0] div_phase;      // 0: none, 1: first division, 2: second division
reg div_start;
reg [21:0] dividend_reg;
reg [7:0] divisor_reg;
reg [5:0] div_counter;
reg [21:0] rem_reg;
reg [23:0] quotient_reg;
reg div_done;

// Pair calculation
reg [23:0] pair_d0;
reg [23:0] pair_d1;
reg [23:0] pair_sum;
reg pair_valid;

// Temporary math registers
reg [17:0] temp_mult1;  // For a*p
reg [17:0] temp_mult2;  // For b*q  
reg [17:0] temp_mult3;  // For a*q
reg [17:0] temp_mult4;  // For b*p
reg [15:0] temp_denom1;
reg [15:0] temp_denom2;

// For single project calculations
reg [23:0] single_max;
reg [21:0] p_scaled;
reg [21:0] q_scaled;

// Initialization and state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 24'd0;
        best_result <= 24'hFFFFFF;  // Initialize to max (32767.999)
        idx_i <= 4'd0;
        idx_j <= 4'd0;
        div_start <= 1'b0;
        div_counter <= 6'd0;
        div_done <= 1'b0;
        div_phase <= 2'd0;
        pair_valid <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= LOAD;
                    idx_i <= 4'd0;
                    best_result <= 24'hFFFFFF;
                end
            end
            
            LOAD: begin
                // Ready to compute, start with single projects
                state <= COMPUTE;
                idx_i <= 4'd0;
                idx_j <= 4'd1;
            end
            
            COMPUTE: begin
                // First compute all single project scenarios
                if (idx_i < n) begin
                    // Single project: max(p/a_i, q/b_i)
                    if (div_phase == 2'd0) begin
                        // Setup first division: p / a[idx_i]
                        p_scaled <= {p, 12'd0};  // p * 4096
                        div_start <= 1'b1;
                        dividend_reg <= {p, 12'd0};
                        divisor_reg <= a[idx_i];
                        div_phase <= 2'd1;
                        state <= DIVIDE;
                    end else if (div_phase == 2'd1) begin
                        // Setup second division: q / b[idx_i]
                        q_scaled <= {q, 12'd0};  // q * 4096
                        div_start <= 1'b1;
                        dividend_reg <= {q, 12'd0};
                        divisor_reg <= b[idx_i];
                        div_phase <= 2'd2;
                        state <= DIVIDE;
                    end else begin
                        // Both done, compare
                        if (temp_result > temp_result2) begin
                            current_max <= temp_result;
                        end else begin
                            current_max <= temp_result2;
                        end
                        div_phase <= 2'd0;
                        state <= UPDATE_BEST;
                    end
                end else begin
                    // All singles done, move to pairs
                    state <= NEXT_PAIR;
                    idx_i <= 4'd0;
                    idx_j <= 4'd1;
                end
            end
            
            DIVIDE: begin
                div_start <= 1'b0;
                div_done <= 1'b0;
                
                if (div_counter == 6'd0) begin
                    // Initialize division
                    rem_reg <= dividend_reg;
                    quotient_reg <= 24'd0;
                    div_counter <= 6'd1;
                end else if (div_counter <= 6'd24) begin
                    // Perform restoring division (24 bits for Q12.12)
                    if (divisor_reg != 8'd0) begin
                        // Shift left
                        rem_reg <= rem_reg << 1;
                        quotient_reg <= quotient_reg << 1;
                        
                        // Check if we can subtract
                        if (rem_reg[21:14] >= divisor_reg) begin
                            rem_reg[21:14] <= rem_reg[21:14] - divisor_reg;
                            quotient_reg[0] <= 1'b1;
                        end
                    end
                    
                    if (div_counter == 6'd24) begin
                        div_counter <= 6'd0;
                        div_done <= 1'b1;
                        
                        // Store result in appropriate temp
                        if (div_phase == 2'd1) begin
                            temp_result <= quotient_reg;
                        end else if (div_phase == 2'd2) begin
                            temp_result2 <= quotient_reg;
                        end
                        
                        state <= COMPUTE;
                    end else begin
                        div_counter <= div_counter + 6'd1;
                    end
                end
            end
            
            UPDATE_BEST: begin
                // Update best result with single project
                if (current_max < best_result) begin
                    best_result <= current_max;
                end
                idx_i <= idx_i + 1;
                div_phase <= 2'd0;
                state <= COMPUTE;
            end
            
            NEXT_PAIR: begin
                if (idx_i < n && idx_j < n) begin
                    // Check if pair is valid (non-parallel)
                    // Compute denominator: a_i*b_j - b_i*a_j
                    if (a[idx_i] * b[idx_j] != b[idx_i] * a[idx_j]) begin
                        // Valid pair, compute intersection
                        state <= COMPUTE;
                        div_phase <= 2'd0;
                        
                        // Setup calculations
                        // d0 = (b_j*p - a_j*q) / (a_i*b_j - b_i*a_j)
                        // d1 = -(b_i*p - a_i*q) / (a_i*b_j - b_i*a_j)
                        
                        temp_mult1 <= a[idx_j] * p;  // a_j * p
                        temp_mult2 <= b[idx_j] * q;  // b_j * q
                        temp_mult3 <= b[idx_i] * p;  // b_i * p
                        temp_mult4 <= a[idx_i] * q;  // a_i * q
                        temp_denom1 <= a[idx_i] * b[idx_j];  // a_i * b_j
                        temp_denom2 <= b[idx_i] * a[idx_j];  // b_i * a_j
                    end else begin
                        // Skip to next pair
                        if (idx_j == n - 1) begin
                            idx_i <= idx_i + 1;
                            idx_j <= idx_i + 2;
                        end else begin
                            idx_j <= idx_j + 1;
                        end
                    end
                end else begin
                    state <= COMPLETE;
                end
            end
            
            COMPLETE: begin
                result <= best_result;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule