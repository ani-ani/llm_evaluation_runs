module triangle_ways(
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [15:0] c,
    input wire [7:0] l,
    input wire start,
    input wire clk,
    input wire rst_n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_TOTAL = 3'd1;
    localparam [2:0] COMPUTE_VIOLATE_A = 3'd2;
    localparam [2:0] COMPUTE_VIOLATE_B = 3'd3;
    localparam [2:0] COMPUTE_VIOLATE_C = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Loop counters
    reg [7:0] i;  // 0 to l
    reg [63:0] total_comb;
    reg [63:0] violate_sum;
    reg [63:0] current_violate;
    
    // Temporary storage for arithmetic
    reg [63:0] temp_sum;
    reg [31:0] n_val;
    reg [63:0] comb_val;
    reg [63:0] s_val;
    reg [31:0] k_val;
    
    // Selection signals
    reg sel_a, sel_b, sel_c;
    reg [15:0] stick1, stick2, stick3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            total_comb <= 64'd0;
            violate_sum <= 64'd0;
            current_violate <= 64'd0;
            i <= 8'd0;
            temp_sum <= 64'd0;
            n_val <= 32'd0;
            comb_val <= 64'd0;
            s_val <= 64'd0;
            k_val <= 32'd0;
            sel_a <= 1'b0;
            sel_b <= 1'b0;
            sel_c <= 1'b0;
            stick1 <= 16'd0;
            stick2 <= 16'd0;
            stick3 <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 64'd0;
                    if (start) begin
                        state <= COMPUTE_TOTAL;
                        total_comb <= 64'd0;
                        violate_sum <= 64'd0;
                        i <= 8'd0;
                    end
                end
                
                COMPUTE_TOTAL: begin
                    // Total combinations = C(l+3, 3)
                    // = (l+1)*(l+2)*(l+3) / 6
                    temp_sum <= (64'd1 + l) * (64'd2 + l) * (64'd3 + l);
                    // Divide by 6 (shift left then divide)
                    total_comb <= ((64'd1 + l) * (64'd2 + l) * (64'd3 + l)) / 64'd6;
                    
                    // Prepare for violation calculation (stick A)
                    stick1 <= a;
                    stick2 <= b;
                    stick3 <= c;
                    i <= 8'd0;
                    state <= COMPUTE_VIOLATE_A;
                end
                
                COMPUTE_VIOLATE_A: begin
                    // s = a - b - c (may be negative)
                    // We compute (a - b - c) + i for each i
                    // Since a,b,c are unsigned, we need to handle wrap-around
                    // In hardware, a - b - c + i = (a + i) - (b + c)
                    
                    if (i <= l) begin
                        // Compute k = min(s + i, l - i)
                        // s = stick1 - stick2 - stick3 (signed)
                        // Since all are >= 1, and l <= 16, we can compute directly
                        // stick1 + i - stick2 - stick3
                        
                        if ((stick1 + i) > (stick2 + stick3)) begin
                            // s + i > 0, so violation possible
                            s_val <= (stick1 + i) - stick2 - stick3;
                        end else begin
                            s_val <= 64'd0;
                        end
                        
                        i <= i + 8'd1;
                    end else begin
                        // Done with stick A, prepare for stick B
                        stick1 <= b;
                        stick2 <= a;
                        stick3 <= c;
                        i <= 8'd0;
                        state <= COMPUTE_VIOLATE_B;
                    end
                end
                
                COMPUTE_VIOLATE_B: begin
                    if (i <= l) begin
                        if ((stick1 + i) > (stick2 + stick3)) begin
                            s_val <= (stick1 + i) - stick2 - stick3;
                        end else begin
                            s_val <= 64'd0;
                        end
                        i <= i + 8'd1;
                    end else begin
                        // Done with stick B, prepare for stick C
                        stick1 <= c;
                        stick2 <= a;
                        stick3 <= b;
                        i <= 8'd0;
                        state <= COMPUTE_VIOLATE_C;
                    end
                end
                
                COMPUTE_VIOLATE_C: begin
                    if (i <= l) begin
                        if ((stick1 + i) > (stick2 + stick3)) begin
                            s_val <= (stick1 + i) - stick2 - stick3;
                        end else begin
                            s_val <= 64'd0;
                        end
                        i <= i + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= total_comb - violate_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for violation calculation
    // k = min(s + i, l - i)
    // C(k+1, 2) = (k+1)*k/2
    always @(*) begin
        // Compute k based on current state
        if ((state == COMPUTE_VIOLATE_A || state == COMPUTE_VIOLATE_B || state == COMPUTE_VIOLATE_C) && i > 8'd0) begin
            // k = min(s_val, l - (i-1)) where i-1 is current index
            if (s_val <= (l - i + 1)) begin
                k_val = s_val[31:0];
            end else begin
                k_val = l - i + 1;
            end
            
            // C(k+1, 2) = (k+1)*k/2
            if (k_val > 32'd0) begin
                comb_val = (64'd1 + k_val) * k_val / 64'd2;
            end else begin
                comb_val = 64'd0;
            end
        end else begin
            k_val = 32'd0;
            comb_val = 64'd0;
        end
        
        // Accumulate violation sum
        if ((state == COMPUTE_VIOLATE_A || state == COMPUTE_VIOLATE_B || state == COMPUTE_VIOLATE_C) && i > 8'd0) begin
            current_violate = comb_val;
        end else begin
            current_violate = 64'd0;
        end
    end
    
    // Accumulate violation sums
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            violate_sum <= 64'd0;
        end else begin
            if ((state == COMPUTE_VIOLATE_A || state == COMPUTE_VIOLATE_B || state == COMPUTE_VIOLATE_C) && i > 8'd0) begin
                violate_sum <= violate_sum + current_violate;
            end
            
            // Reset when starting new calculation
            if (state == COMPUTE_TOTAL && next_state != COMPUTE_TOTAL) begin
                violate_sum <= 64'd0;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_TOTAL;
                else next_state = IDLE;
            end
            COMPUTE_TOTAL: next_state = COMPUTE_VIOLATE_A;
            COMPUTE_VIOLATE_A: begin
                if (i > l) next_state = COMPUTE_VIOLATE_B;
                else next_state = COMPUTE_VIOLATE_A;
            end
            COMPUTE_VIOLATE_B: begin
                if (i > l) next_state = COMPUTE_VIOLATE_C;
                else next_state = COMPUTE_VIOLATE_B;
            end
            COMPUTE_VIOLATE_C: begin
                if (i > l) next_state = FINISH;
                else next_state = COMPUTE_VIOLATE_C;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
endmodule