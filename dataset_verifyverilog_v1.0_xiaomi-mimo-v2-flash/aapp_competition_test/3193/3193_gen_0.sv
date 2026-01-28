module slon_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] a,
    input wire [19:0] b,
    input wire [19:0] P,
    input wire [19:0] M,
    output reg [19:0] x_out,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_DATA = 4'd1;
    localparam [3:0] CHECK_A_ZERO = 4'd2;
    localparam [3:0] PREP_EUCLID = 4'd3;
    localparam [3:0] EUCLID_LOOP = 4'd4;
    localparam [3:0] EUCLID_UPDATE = 4'd5;
    localparam [3:0] CHECK_RESULT = 4'd6;
    localparam [3:0] ADJUST_SIGN = 4'd7;
    localparam [3:0] COMPUTE_X = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    reg [3:0] state, next_state;
    
    // Internal registers
    reg [19:0] a_reg, b_reg, P_reg, M_reg;
    reg [19:0] target; // (P - b) % M
    reg [19:0] x_result;
    
    // Extended Euclidean Algorithm registers
    reg [19:0] old_r, r, old_s, s, old_t, t;
    reg [19:0] temp_val;
    reg [19:0] quotient;
    reg [19:0] mod_inv_a; // modular inverse of a
    reg euclid_done;
    reg euclid_success;
    
    // Multiplication result register
    reg [39:0] mult_result; // 20*20 = 40 bits
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD_DATA : IDLE;
            
            LOAD_DATA: next_state = CHECK_A_ZERO;
            
            CHECK_A_ZERO: begin
                if (a_reg == 20'd0) begin
                    next_state = CHECK_RESULT; // Skip Euclid, check target
                end else begin
                    next_state = PREP_EUCLID;
                end
            end
            
            PREP_EUCLID: next_state = EUCLID_LOOP;
            
            EUCLID_LOOP: begin
                if (r == 20'd0) begin
                    next_state = CHECK_RESULT;
                end else if (cycle_count >= 8'd100) begin
                    next_state = CHECK_RESULT; // Timeout protection
                end else begin
                    next_state = EUCLID_UPDATE;
                end
            end
            
            EUCLID_UPDATE: next_state = EUCLID_LOOP;
            
            CHECK_RESULT: begin
                if (euclid_success) begin
                    next_state = COMPUTE_X;
                end else begin
                    // a=0, target!=0 or no inverse case - should not happen per spec
                    next_state = FINISH;
                end
            end
            
            COMPUTE_X: next_state = ADJUST_SIGN;
            
            ADJUST_SIGN: next_state = FINISH;
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_out <= 20'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all internal regs
            a_reg <= 20'd0;
            b_reg <= 20'd0;
            P_reg <= 20'd0;
            M_reg <= 20'd0;
            target <= 20'd0;
            x_result <= 20'd0;
            old_r <= 20'd0;
            r <= 20'd0;
            old_s <= 20'd0;
            s <= 20'd0;
            old_t <= 20'd0;
            t <= 20'd0;
            quotient <= 20'd0;
            mod_inv_a <= 20'd0;
            euclid_done <= 1'b0;
            euclid_success <= 1'b0;
            mult_result <= 40'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                LOAD_DATA: begin
                    a_reg <= a;
                    b_reg <= b;
                    P_reg <= P;
                    M_reg <= M;
                    euclid_success <= 1'b0;
                end
                
                CHECK_A_ZERO: begin
                    // Compute target = (P - b) % M
                    // Handle negative case
                    if (P_reg >= b_reg) begin
                        target <= (P_reg - b_reg) % M_reg;
                    end else begin
                        // P - b is negative, add M until positive
                        // Since P and b < M, P - b > -M, so (P - b + M) is positive
                        target <= (P_reg + M_reg - b_reg) % M_reg;
                    end
                    
                    if (a_reg == 20'd0) begin
                        if (target == 20'd0) begin
                            x_result <= 20'd0;
                            euclid_success <= 1'b1;
                        end else begin
                            euclid_success <= 1'b0;
                        end
                    end
                end
                
                PREP_EUCLID: begin
                    old_r <= a_reg;
                    r <= M_reg;
                    old_s <= 20'd1;
                    s <= 20'd0;
                    old_t <= 20'd0;
                    t <= 20'd1;
                    euclid_done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                EUCLID_LOOP: begin
                    // Check for completion
                    if (r == 20'd0 && euclid_done == 1'b0) begin
                        euclid_done <= 1'b1;
                        if (old_s != 20'd0) begin
                            // inverse found (old_r is the gcd)
                            // Check if gcd is 1 (for mod inverse)
                            if (old_r == 20'd1) begin
                                euclid_success <= 1'b1;
                                mod_inv_a <= old_s;
                            end else begin
                                // gcd > 1, no inverse (shouldn't happen per spec)
                                euclid_success <= 1'b0;
                            end
                        end
                    end
                end
                
                EUCLID_UPDATE: begin
                    if (r != 20'd0) begin
                        quotient <= old_r / r;
                        temp_val <= r;
                    end
                end
                
                CHECK_RESULT: begin
                    // Update Euclidean algorithm variables
                    if (cycle_count < 8'd100 && r != 20'd0) begin
                        // r_new = old_r - q * r
                        // s_new = old_s - q * s
                        // t_new = old_t - q * t
                        old_r <= r;
                        old_s <= s;
                        old_t <= t;
                        r <= old_r - (quotient * r);
                        s <= old_s - (quotient * s);
                        t <= old_t - (quotient * t);
                        cycle_count <= cycle_count + 8'd1;
                    end
                end
                
                COMPUTE_X: begin
                    // x = (target * mod_inv_a) % M
                    // Use 40-bit multiplication, then modulo
                    if (euclid_success) begin
                        mult_result <= target * mod_inv_a;
                    end
                end
                
                ADJUST_SIGN: begin
                    // Compute modulo M
                    x_result <= mult_result % M_reg;
                end
                
                FINISH: begin
                    x_out <= x_result;
                    done <= 1'b1;
                end
                
                default: begin
                    // Reset to safe state
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule