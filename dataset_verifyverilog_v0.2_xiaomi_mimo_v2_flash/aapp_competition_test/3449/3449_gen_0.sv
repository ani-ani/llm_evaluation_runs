module NightClubLighting(
    input clk,
    input rst_n,
    input start,
    input [3:0] B,  // min light level 1-9
    input [3:0] H,  // ceiling height 1-5
    input [5:0] R,  // rows 1-8
    input [5:0] C,  // cols 1-8
    // Grid inputs (8x8 flattened) - strengths 0-9
    input [3:0] g00, g01, g02, g03, g04, g05, g06, g07,
    input [3:0] g10, g11, g12, g13, g14, g15, g16, g17,
    input [3:0] g20, g21, g22, g23, g24, g25, g26, g27,
    input [3:0] g30, g31, g32, g33, g34, g35, g36, g37,
    input [3:0] g40, g41, g42, g43, g44, g45, g46, g47,
    input [3:0] g50, g51, g52, g53, g54, g55, g56, g57,
    input [3:0] g60, g61, g62, g63, g64, g65, g66, g67,
    input [3:0] g70, g71, g72, g73, g74, g75, g76, g77,
    output reg [15:0] cost,
    output reg done
);

    // Fixed-point: Q16.16 (32-bit)
    localparam INT_BITS = 16;
    localparam FRAC_BITS = 16;
    localparam TOTAL_BITS = 32;
    localparam ONE_POINT_ZERO = 32'h00010000;

    // FSM states
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE_LIGHTS = 3'b010;
    localparam CHECK_DARK = 3'b011;
    localparam CALC_COST = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;
    
    // Internal grid storage (8x8)
    reg [3:0] grid [0:7][0:7];
    reg [TOTAL_BITS-1:0] light_level [0:7][0:7];
    reg dark [0:7][0:7];
    
    // Counters and indices
    reg [2:0] i, j;  // current cell being processed
    reg [2:0] lr, lc;  // light row and col
    reg [2:0] cr, cc;  // cell row and col for cost calc
    
    // Temporary values for calculation
    reg [TOTAL_BITS-1:0] temp_light;
    reg [TOTAL_BITS-1:0] dist_sq;
    reg [TOTAL_BITS-1:0] contrib;
    reg [15:0] temp_cost;
    reg [3:0] strength_val;
    
    // Division control (restoring division)
    reg div_start;
    reg [TOTAL_BITS-1:0] div_numer;
    reg [TOTAL_BITS-1:0] div_denom;
    wire [TOTAL_BITS-1:0] div_quotient;
    wire div_done;
    
    // Simple division module (combinational for Q16.16)
    // This is a simplified version - in practice would be iterative
    assign div_quotient = (div_denom != 0) ? (div_numer << FRAC_BITS) / div_denom : 0;
    assign div_done = 1'b1;  // Combinational

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                next_state = COMPUTE_LIGHTS;
            end
            COMPUTE_LIGHTS: begin
                if (i >= R || j >= C) begin
                    if (lr >= R || lc >= C)
                        next_state = CHECK_DARK;
                    else
                        next_state = COMPUTE_LIGHTS;
                end else begin
                    next_state = COMPUTE_LIGHTS;
                end
            end
            CHECK_DARK: begin
                if (i >= R)
                    next_state = CALC_COST;
                else
                    next_state = CHECK_DARK;
            end
            CALC_COST: begin
                if (cr >= R-1 && cc >= C-1)
                    next_state = DONE;
                else
                    next_state = CALC_COST;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            cost <= 0;
            i <= 0; j <= 0;
            lr <= 0; lc <= 0;
            cr <= 0; cc <= 0;
            div_start <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    cost <= 0;
                end
                
                LOAD: begin
                    // Load grid from inputs into 2D array
                    grid[0][0] <= g00; grid[0][1] <= g01; grid[0][2] <= g02; grid[0][3] <= g03;
                    grid[0][4] <= g04; grid[0][5] <= g05; grid[0][6] <= g06; grid[0][7] <= g07;
                    grid[1][0] <= g10; grid[1][1] <= g11; grid[1][2] <= g12; grid[1][3] <= g13;
                    grid[1][4] <= g14; grid[1][5] <= g15; grid[1][6] <= g16; grid[1][7] <= g17;
                    grid[2][0] <= g20; grid[2][1] <= g21; grid[2][2] <= g22; grid[2][3] <= g23;
                    grid[2][4] <= g24; grid[2][5] <= g25; grid[2][6] <= g26; grid[2][7] <= g27;
                    grid[3][0] <= g30; grid[3][1] <= g31; grid[3][2] <= g32; grid[3][3] <= g33;
                    grid[3][4] <= g34; grid[3][5] <= g35; grid[3][6] <= g36; grid[3][7] <= g37;
                    grid[4][0] <= g40; grid[4][1] <= g41; grid[4][2] <= g42; grid[4][3] <= g43;
                    grid[4][4] <= g44; grid[4][5] <= g45; grid[4][6] <= g46; grid[4][7] <= g47;
                    grid[5][0] <= g50; grid[5][1] <= g51; grid[5][2] <= g52; grid[5][3] <= g53;
                    grid[5][4] <= g54; grid[5][5] <= g55; grid[5][6] <= g56; grid[5][7] <= g57;
                    grid[6][0] <= g60; grid[6][1] <= g61; grid[6][2] <= g62; grid[6][3] <= g63;
                    grid[6][4] <= g64; grid[6][5] <= g65; grid[6][6] <= g66; grid[6][7] <= g67;
                    grid[7][0] <= g70; grid[7][1] <= g71; grid[7][2] <= g72; grid[7][3] <= g73;
                    grid[7][4] <= g74; grid[7][5] <= g75; grid[7][6] <= g76; grid[7][7] <= g77;
                    // Initialize light levels to 0
                    light_level[0][0] <= 0; light_level[0][1] <= 0; light_level[0][2] <= 0; light_level[0][3] <= 0;
                    light_level[0][4] <= 0; light_level[0][5] <= 0; light_level[0][6] <= 0; light_level[0][7] <= 0;
                    light_level[1][0] <= 0; light_level[1][1] <= 0; light_level[1][2] <= 0; light_level[1][3] <= 0;
                    light_level[1][4] <= 0; light_level[1][5] <= 0; light_level[1][6] <= 0; light_level[1][7] <= 0;
                    light_level[2][0] <= 0; light_level[2][1] <= 0; light_level[2][2] <= 0; light_level[2][3] <= 0;
                    light_level[2][4] <= 0; light_level[2][5] <= 0; light_level[2][6] <= 0; light_level[2][7] <= 0;
                    light_level[3][0] <= 0; light_level[3][1] <= 0; light_level[3][2] <= 0; light_level[3][3] <= 0;
                    light_level[3][4] <= 0; light_level[3][5] <= 0; light_level[3][6] <= 0; light_level[3][7] <= 0;
                    light_level[4][0] <= 0; light_level[4][1] <= 0; light_level[4][2] <= 0; light_level[4][3] <= 0;
                    light_level[4][4] <= 0; light_level[4][5] <= 0; light_level[4][6] <= 0; light_level[4][7] <= 0;
                    light_level[5][0] <= 0; light_level[5][1] <= 0; light_level[5][2] <= 0; light_level[5][3] <= 0;
                    light_level[5][4] <= 0; light_level[5][5] <= 0; light_level[5][6] <= 0; light_level[5][7] <= 0;
                    light_level[6][0] <= 0; light_level[6][1] <= 0; light_level[6][2] <= 0; light_level[6][3] <= 0;
                    light_level[6][4] <= 0; light_level[6][5] <= 0; light_level[6][6] <= 0; light_level[6][7] <= 0;
                    light_level[7][0] <= 0; light_level[7][1] <= 0; light_level[7][2] <= 0; light_level[7][3] <= 0;
                    light_level[7][4] <= 0; light_level[7][5] <= 0; light_level[7][6] <= 0; light_level[7][7] <= 0;
                    i <= 0; j <= 0;
                    lr <= 0; lc <= 0;
                end
                
                COMPUTE_LIGHTS: begin
                    // For cell (i,j), accumulate light from all sources (lr,lc)
                    if (i < R && j < C && lr < R && lc < C) begin
                        // Calculate distance squared: (i-lr)^2 + (j-lc)^2 + H^2
                        // Use absolute differences
                        reg [3:0] dr, dc;
                        dr = (i > lr) ? (i - lr) : (lr - i);
                        dc = (j > lc) ? (j - lc) : (lc - j);
                        dist_sq = (dr * dr + dc * dc + H * H);
                        
                        if (dist_sq > 0 && grid[lr][lc] > 0) begin
                            // contribution = strength / dist_sq in Q16.16
                            // Using combinational division
                            strength_val = grid[lr][lc];
                            div_numer = {16'b0, strength_val, 16'b0};  // strength in Q16.0
                            div_denom = dist_sq;
                            contrib = div_quotient;  // Q16.16 result
                            light_level[i][j] <= light_level[i][j] + contrib;
                        end
                    end
                    
                    // Update counters
                    if (lr < R - 1) begin
                        lc <= lc + 1;
                        if (lc == C - 1) begin
                            lc <= 0;
                            lr <= lr + 1;
                        end
                    end else if (lc < C - 1) begin
                        lc <= lc + 1;
                    end else begin
                        // Done with all lights for current cell
                        lc <= 0;
                        lr <= 0;
                        if (j < C - 1) begin
                            j <= j + 1;
                        end else if (i < R - 1) begin
                            i <= i + 1;
                            j <= 0;
                        end else begin
                            // All cells processed
                            i <= 0;
                            j <= 0;
                        end
                    end
                end
                
                CHECK_DARK: begin
                    // Check if light_level[i][j] < B
                    // Convert B to Q16.16: B << 16
                    if (light_level[i][j] < (B << FRAC_BITS))
                        dark[i][j] <= 1;
                    else
                        dark[i][j] <= 0;
                    
                    // Increment counters
                    if (j < C - 1)
                        j <= j + 1;
                    else begin
                        j <= 0;
                        if (i < R - 1)
                            i <= i + 1;
                        else
                            i <= 0;
                    end
                end
                
                CALC_COST: begin
                    // For each internal cell (cr, cc) where 0 < cr < R-1, 0 < cc < C-1
                    // Check right neighbor (cr, cc+1) and bottom neighbor (cr+1, cc)
                    if (cr < R - 1 && cc < C - 1) begin
                        // Check right edge
                        if (cc < C - 1) begin
                            if (dark[cr][cc] ^ dark[cr][cc+1]) begin
                                temp_cost = cost + 16'd11;
                                cost <= temp_cost;
                            end
                        end
                        // Check bottom edge
                        if (cr < R - 1) begin
                            if (dark[cr][cc] ^ dark[cr+1][cc]) begin
                                temp_cost = cost + 16'd11;
                                cost <= temp_cost;
                            end
                        end
                    end
                    
                    // Increment counters
                    if (cc < C - 2)
                        cc <= cc + 1;
                    else begin
                        cc <= 0;
                        if (cr < R - 2)
                            cr <= cr + 1;
                        else
                            cr <= 0;
                    end
                end
                
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
