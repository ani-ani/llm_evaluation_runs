module luggage_speed(
    input clk,
    input rst_n,
    input start,
    input [7:0] pos [0:3],
    input [2:0] num_luggage,
    input [7:0] L,
    output reg [15:0] v,
    output reg done
);
    // Parameters
    localparam MAX_N = 4;
    localparam POS_WIDTH = 8;
    localparam L_WIDTH = 8;
    localparam V_INT_WIDTH = 8;
    localparam V_FRAC_WIDTH = 8;
    
    // Fixed-point conversion factors
    localparam [15:0] FP_0_1 = 16'd25;   // 0.1 * 256 (for FRAC_WIDTH=8)
    localparam [15:0] FP_10 = 16'd2560;  // 10 * 256
    
    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LATCH = 4'd1;
    localparam [3:0] COMPUTE_DIFF = 4'd2;
    localparam [3:0] ITERATE_K = 4'd3;
    localparam [3:0] CALC_A = 4'd4;
    localparam [3:0] CALC_B = 4'd5;
    localparam [3:0] INTERSECT = 4'd6;
    localparam [3:0] FIND_MAX = 4'd7;
    localparam [3:0] FINISH = 4'd8;
    
    reg [3:0] state, next_state;
    reg [7:0] cycles;
    reg [1:0] i, j;
    reg [2:0] k;
    reg [7:0] pos_reg [0:3];
    reg [7:0] num_reg;
    reg [7:0] L_reg;
    reg [7:0] d;
    reg [15:0] denom1, denom2;
    reg [15:0] a, b;
    reg [15:0] min_v, max_v;
    reg signed [15:0] diff;
    reg [15:0] max_allowed;
    reg [2:0] pair_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            v <= 16'd0;
            min_v <= FP_0_1;
            max_v <= FP_10;
            cycles <= 8'd0;
            for (integer m = 0; m < MAX_N; m = m + 1) pos_reg[m] <= 8'd0;
            num_reg <= 3'd0;
            L_reg <= 8'd0;
        end else begin
            cycles <= cycles + 8'd1;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LATCH;
                        min_v <= FP_0_1;
                        max_v <= FP_10;
                    end
                end
                
                LATCH: begin
                    num_reg <= num_luggage;
                    L_reg <= L;
                    for (integer m = 0; m < MAX_N; m = m + 1) begin
                        if (m < num_luggage) pos_reg[m] <= pos[m];
                        else pos_reg[m] <= 8'd0;
                    end
                    i <= 2'd0;
                    j <= 2'd1;
                    pair_count <= 3'd0;
                    next_state <= COMPUTE_DIFF;
                end
                
                COMPUTE_DIFF: begin
                    diff = pos_reg[i] - pos_reg[j];
                    d = (diff >= 0) ? diff : -diff;
                    k <= 3'd0;
                    next_state <= ITERATE_K;
                end
                
                ITERATE_K: begin
                    denom1 = (k * L_reg) + (L_reg - 8'd1);
                    denom2 = (k * L_reg) + 8'd1;
                    next_state <= CALC_A;
                end
                
                CALC_A: begin
                    // Fixed-point division: d * 256 / denom1
                    a <= (d << V_FRAC_WIDTH) / denom1;
                    next_state <= CALC_B;
                end
                
                CALC_B: begin
                    // Fixed-point division: d * 256 / denom2
                    b <= (d << V_FRAC_WIDTH) / denom2;
                    next_state <= INTERSECT;
                end
                
                INTERSECT: begin
                    // Intersect new interval with global
                    if (a > min_v) min_v <= a;
                    if (b < max_v) max_v <= b;
                    
                    k <= k + 3'd1;
                    if (k < 3'd5) next_state <= ITERATE_K;
                    else begin
                        j <= j + 2'd1;
                        if (j >= num_reg) begin
                            i <= i + 2'd1;
                            j <= i + 2'd1;
                            pair_count <= pair_count + 3'd1;
                        end
                        
                        if (pair_count == (num_reg*(num_reg-1)/2)-1)
                            next_state <= FIND_MAX;
                        else
                            next_state <= COMPUTE_DIFF;
                    end
                end
                
                FIND_MAX: begin
                    // Maximum valid v is min(max_v, 10)
                    max_allowed <= (max_v < FP_10) ? max_v : FP_10;
                    next_state <= FINISH;
                end
                
                FINISH: begin
                    v <= (min_v <= max_allowed) ? max_allowed : 16'd0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
            
            if (cycles >= 8'd200) next_state <= FINISH;  // Timeout protection
        end
    end
endmodule