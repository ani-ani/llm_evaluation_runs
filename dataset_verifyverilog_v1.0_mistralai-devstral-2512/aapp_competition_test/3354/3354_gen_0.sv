module PicklePlacer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] s_i,
    input wire [31:0] s_f,
    input wire [31:0] r_i,
    input wire [31:0] r_f,
    input wire [2:0] n,
    input wire [6:0] z,
    output reg [2:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Fixed-point constants
    localparam [31:0] PI = 32'd205887; // Q16.16 approximation of pi
    
    // Internal signals
    reg [2:0] k;
    reg [31:0] s_sq, r_sq, k_r_sq, area_k, area_sandwich;
    reg [31:0] s_val, r_val, s_div_r;
    reg area_ok, geom_ok;
    
    // Calculate s and r in Q16.16
    assign s_val = s_i + s_f;
    assign r_val = r_i + r_f;
    
    // Calculate s/r ratio (Q16.16)
    always @(*) begin
        if (r_val == 32'd0) begin
            s_div_r = 32'd0;
        end else begin
            s_div_r = (s_val << 16) / r_val; // Q16.16 division
        end
    end
    
    // Area calculation
    always @(*) begin
        // Calculate s^2 and r^2 in Q16.16
        s_sq = (s_val * s_val) >> 16; // Q16.16 * Q16.16 = Q32.32, shift to Q16.16
        r_sq = (r_val * r_val) >> 16;
        
        // Calculate k * r^2
        k_r_sq = k * r_sq; // k is integer, r_sq is Q16.16
        
        // Calculate area_k = k * pi * r^2
        area_k = (k_r_sq * PI) >> 16; // Q16.16 * Q16.16 = Q32.32, shift to Q16.16
        
        // Calculate area_sandwich = pi * s^2
        area_sandwich = (s_sq * PI) >> 16;
        
        // Area check: (area_k * 100) <= (area_sandwich * z)
        // Multiply both sides by 100 (Q16.16)
        area_ok = ((area_k * 100) >> 16) <= ((area_sandwich * z) >> 16);
    end
    
    // Geometric check
    always @(*) begin
        case (k)
            3'd0: geom_ok = 1'b1; // k=0 is always valid
            3'd1: geom_ok = (r_val <= s_val); // k=1: r <= s
            3'd2: geom_ok = (2 * r_val) <= s_val; // k=2: 2r <= s
            3'd3: geom_ok = (s_val >= r_val + ((r_val * 1812) >> 16)); // k=3: s >= r + r*sqrt(3) (sqrt(3) ~ 1.732 ~ 1812/1048)
            3'd4: geom_ok = (s_val >= r_val + ((r_val * 1663) >> 16)); // k=4: s >= r + r*sqrt(2) (sqrt(2) ~ 1.414 ~ 1663/1176)
            3'd5: geom_ok = (s_div_r >= 32'd27015); // k=5: s/r >= 2.7015 (Q16.16)
            3'd6: geom_ok = (s_div_r >= 32'd3); // k=6: s/r >= 3 (Q16.16)
            3'd7: geom_ok = (s_div_r >= 32'd3304); // k=7: s/r >= 3.304 (Q16.16)
            default: geom_ok = 1'b0;
        endcase
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            k <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        k <= n; // Start from maximum available pickles
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current k is valid
                    if (area_ok && geom_ok) begin
                        result <= k;
                        state <= FINISH;
                    end else if (k > 3'd0) begin
                        k <= k - 3'd1; // Try next lower k
                    end else begin
                        // No valid configuration found
                        result <= 3'd0;
                        state <= FINISH;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 3'd0;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule