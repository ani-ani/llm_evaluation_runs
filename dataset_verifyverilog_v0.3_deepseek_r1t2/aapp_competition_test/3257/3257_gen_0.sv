module area_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    output reg [31:0] area,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CALC_SQUARES  = 4'd1;
    localparam [3:0] CALC_S        = 4'd2;
    localparam [3:0] CALC_TERMS    = 4'd3;
    localparam [3:0] CHECK_D       = 4'd4;
    localparam [3:0] CALC_SQRT_D   = 4'd5;
    localparam [3:0] CALC_T        = 4'd6;
    localparam [3:0] CHECK_BOUNDS  = 4'd7;
    localparam [3:0] CALC_AREA     = 4'd8;
    localparam [3:0] FINISH        = 4'd9;
    
    reg [3:0] state, next_state;
    reg [31:0] a_reg, b_reg, c_reg;
    reg [31:0] a2, b2, c2;
    reg [31:0] S;
    reg signed [63:0] D_signed;
    reg [63:0] D;
    reg [31:0] sqrt_D;
    reg [31:0] t;
    
    // Square root variables
    reg [5:0] sqrt_counter;
    reg [31:0] q_sqrt;
    reg [65:0] rem_sqrt;
    
    // Lower bound calculation
    reg signed [31:0] diff_ab, diff_term2, diff_term3, diff_term4;
    reg [31:0] abs1, abs2, abs3, abs4;
    reg [31:0] lower1, lower2, lower_bound;
    
    // Cycle counter for timeout
    reg [6:0] cycle_count;
    
    // Constants
    localparam [31:0] SQRT3_4   = 32'd28378; // sqrt(3)/4 in Q16.16
    localparam [31:0] ERR_VAL   = 32'hFFFFFFFF;
    localparam [6:0] MAX_CYCLES = 7'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a_reg <= 32'd0;
            b_reg <= 32'd0;
            c_reg <= 32'd0;
            a2 <= 32'd0;
            b2 <= 32'd0;
            c2 <= 32'd0;
            S <= 32'd0;
            D_signed <= 64'd0;
            D <= 64'd0;
            sqrt_D <= 32'd0;
            t <= 32'd0;
            q_sqrt <= 32'd0;
            rem_sqrt <= 66'd0;
            sqrt_counter <= 6'd0;
            done <= 1'b0;
            cycle_count <= 7'd0;
            area <= 32'd0;
        end else begin
            cycle_count <= (state == IDLE) ? 7'd0 :
                          (cycle_count < MAX_CYCLES) ? cycle_count + 7'd1 : cycle_count;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    area <= area;
                    if (start) begin
                        a_reg <= a;
                        b_reg <= b;
                        c_reg <= c;
                        state <= CALC_SQUARES;
                    end
                end
                
                CALC_SQUARES: begin
                    a2 <= (a_reg * a_reg) >> 16;
                    b2 <= (b_reg * b_reg) >> 16;
                    c2 <= (c_reg * c_reg) >> 16;
                    state <= CALC_S;
                end
                
                CALC_S: begin
                    S <= a2 + b2 + c2;
                    state <= CALC_TERMS;
                end
                
                CALC_TERMS: begin
                    begin
                        reg [63:0] sum_cross = ((a2 * b2) >> 16) + ((a2 * c2) >> 16) + ((b2 * c2) >> 16);
                        reg [63:0] sum_squares = ((a2 * a2) >> 16) + ((b2 * b2) >> 16) + ((c2 * c2) >> 16);
                        reg [63:0] inner = (2 * sum_cross) - sum_squares;
                        D_signed <= inner * 64'sd3;
                        D <= inner * 64'd3;
                    end
                    state <= CHECK_D;
                end
                
                CHECK_D: begin
                    if (D_signed[63] || (cycle_count >= MAX_CYCLES)) begin
                        area <= ERR_VAL;
                        state <= FINISH;
                    end else begin
                        q_sqrt <= 32'd0;
                        rem_sqrt <= {D, 2'd0};
                        sqrt_counter <= 6'd0;
                        state <= CALC_SQRT_D;
                    end
                end
                
                CALC_SQRT_D: begin
                    if (sqrt_counter < 6'd32) begin
                        if (rem_sqrt >= ({q_sqrt, 2'b01})) begin
                            rem_sqrt <= rem_sqrt - {q_sqrt, 2'b01};
                            q_sqrt <= { q_sqrt[30:0], 1'b1 };
                        end else begin
                            q_sqrt <= { q_sqrt[30:0], 1'b0 };
                        end
                        rem_sqrt <= rem_sqrt << 2;
                        sqrt_counter <= sqrt_counter + 6'd1;
                    end else begin
                        sqrt_D <= q_sqrt;
                        state <= CALC_T;
                    end
                end
                
                CALC_T: begin
                    t <= (S + sqrt_D) >> 1;
                    // Calculate absolute values
                    diff_ab = signed'(a2 - b2);
                    abs1 = (diff_ab >= 0) ? diff_ab : -diff_ab;
                    
                    diff_term2 = signed'(2 * c2 - a2 - b2);
                    abs2 = (diff_term2 >= 0) ? diff_term2 : -diff_term2;
                    
                    diff_term3 = signed'(2 * b2 - a2 - c2);
                    abs3 = (diff_term3 >= 0) ? diff_term3 : -diff_term3;
                    
                    diff_term4 = signed'(2 * a2 - b2 - c2);
                    abs4 = (diff_term4 >= 0) ? diff_term4 : -diff_term4;
                    
                    lower1 = (abs1 > abs2) ? abs1 : abs2;
                    lower2 = (abs3 > abs4) ? abs3 : abs4;
                    lower_bound = (lower1 > lower2) ? lower1 : lower2;
                    
                    state <= CHECK_BOUNDS;
                end
                
                CHECK_BOUNDS: begin
                    if (t < lower_bound) begin
                        area <= ERR_VAL;
                    end
                    state <= CALC_AREA;
                end
                
                CALC_AREA: begin
                    if (area != ERR_VAL)
                        area <= (SQRT3_4 * t) >> 16;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) area <= ERR_VAL;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Force error on timeout
            if (cycle_count >= MAX_CYCLES) begin
                area <= ERR_VAL;
                state <= FINISH;
            end
        end
    end
    
endmodule