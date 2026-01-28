module currency_exchange(
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    input [7:0] d,
    input [7:0] e,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] COMPUTE_N_MOD = 3'd1;
    localparam [2:0] LOOP_INIT     = 3'd2;
    localparam [2:0] LOOP_BODY     = 3'd3;
    localparam [2:0] LOOP_CHECK    = 3'd4;
    localparam [2:0] DONE          = 3'd5;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Input storage
    reg [31:0] n_reg;
    reg [7:0] d_reg;
    reg [7:0] e_reg;
    
    // Intermediate values
    reg [31:0] B;                  // 5 * e
    reg [31:0] temp_n;             // n for modulo computation
    reg [7:0] n_mod_d;             // n % d
    
    // Modulo computation variables
    reg [4:0] bit_counter;         // Counter for 32 bits
    reg [7:0] remainder_temp;      // Temporary remainder during modulo calc
    reg [31:0] shifted_n;          // Shifted version of n for processing
    
    // Loop variables
    reg [7:0] i;                   // Loop counter (j)
    reg [31:0] iB;                 // i * B
    reg [7:0] iB_mod_d;            // (i * B) % d
    reg [7:0] min_rem;             // Minimum leftover found
    reg [7:0] rem;                 // Current remainder
    reg [7:0] temp_diff;           // Temporary for subtraction
    
    // Helper flags
    reg break_loop;                // Flag to break out of loop
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE_N_MOD;
                else
                    next_state = IDLE;
            end
            
            COMPUTE_N_MOD: begin
                if (bit_counter == 5'd32)
                    next_state = LOOP_INIT;
                else
                    next_state = COMPUTE_N_MOD;
            end
            
            LOOP_INIT: begin
                next_state = LOOP_BODY;
            end
            
            LOOP_BODY: begin
                if (break_loop)
                    next_state = DONE;
                else
                    next_state = LOOP_CHECK;
            end
            
            LOOP_CHECK: begin
                if (i >= d_reg)
                    next_state = DONE;
                else
                    next_state = LOOP_BODY;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State transition and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            
            // Reset all registers
            n_reg <= 32'd0;
            d_reg <= 8'd0;
            e_reg <= 8'd0;
            B <= 32'd0;
            n_mod_d <= 8'd0;
            bit_counter <= 5'd0;
            remainder_temp <= 8'd0;
            shifted_n <= 32'd0;
            i <= 8'd0;
            iB <= 32'd0;
            iB_mod_d <= 8'd0;
            min_rem <= 8'hFF;
            rem <= 8'd0;
            temp_diff <= 8'd0;
            break_loop <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        n_reg <= n;
                        d_reg <= d;
                        e_reg <= e;
                        B <= 5 * e;  // Compute B = 5 * e
                        
                        // Initialize for modulo computation
                        temp_n <= n;
                        remainder_temp <= 8'd0;
                        bit_counter <= 5'd0;
                        shifted_n <= 32'd0;
                    end
                end
                
                COMPUTE_N_MOD: begin
                    // Compute n % d using shift-add-subtract algorithm
                    // Process bits from MSB to LSB
                    // shifted_n initialization
                    if (bit_counter == 5'd0) begin
                        shifted_n <= n_reg;
                    end else begin
                        // Shift remainder left
                        remainder_temp <= remainder_temp << 1;
                        remainder_temp[0] <= shifted_n[31];  // Add MSB bit
                        
                        // Subtract if remainder >= d
                        if (remainder_temp >= d_reg) begin
                            remainder_temp <= remainder_temp - d_reg;
                        end
                        
                        // Shift shifted_n left
                        shifted_n <= shifted_n << 1;
                    end
                    
                    bit_counter <= bit_counter + 5'd1;
                end
                
                LOOP_INIT: begin
                    // Store n_mod_d from modulo computation
                    n_mod_d <= remainder_temp;
                    
                    // Initialize loop variables
                    i <= 8'd0;
                    iB <= 32'd0;
                    iB_mod_d <= 8'd0;
                    min_rem <= 8'hFF;
                    break_loop <= 1'b0;
                end
                
                LOOP_BODY: begin
                    // Check if j*B > n (i*B > n_reg)
                    if (iB > n_reg) begin
                        break_loop <= 1'b1;
                    end else begin
                        // Compute rem = (n_mod_d - iB_mod_d) mod d
                        if (n_mod_d >= iB_mod_d) begin
                            rem <= n_mod_d - iB_mod_d;
                        end else begin
                            rem <= n_mod_d + d_reg - iB_mod_d;
                        end
                        
                        // Update min_rem
                        if (rem < min_rem) begin
                            min_rem <= rem;
                        end
                        
                        // Increment i and update iB_mod_d
                        i <= i + 8'd1;
                        iB <= iB + B;
                        
                        // Compute (iB + B) % d for next iteration
                        temp_diff <= (iB_mod_d + B[7:0]);
                        
                        // Take mod d of temp_diff
                        if (temp_diff >= d_reg) begin
                            iB_mod_d <= temp_diff - d_reg;
                        end else begin
                            iB_mod_d <= temp_diff;
                        end
                    end
                end
                
                LOOP_CHECK: begin
                    // Update iB_mod_d with actual computation
                    iB_mod_d <= temp_diff % d_reg;
                    // Check done in next_state logic
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= min_rem;
                end
            endcase
        end
    end
endmodule