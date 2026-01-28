module recycling_optimization(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] ax, ay,
    input wire [31:0] bx, by,
    input wire [31:0] tx, ty,
    input wire [2:0] num_bottles,
    input wire [31:0] bottle_x [0:7],
    input wire [31:0] bottle_y [0:7],
    output reg [63:0] total_distance,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_DIST = 3'd1;
    localparam [2:0] FIND_SAVINGS = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [5:0] counter;
    reg [2:0] bottle_idx;
    
    // Distance arrays
    reg [63:0] dist_bin [0:7];
    reg [63:0] dist_adil [0:7];
    reg [63:0] dist_bera [0:7];
    
    // Savings tracking
    reg [63:0] savings_adil [0:7];
    reg [63:0] savings_bera [0:7];
    reg [63:0] best_savings [0:1];
    reg [2:0] best_idx [0:1];
    
    // Fixed-point multiplication
    function automatic [63:0] fp_mult;
        input [31:0] a, b;
        begin
            fp_mult = ({{32{a[31]}}, a} * {{32{b[31]}}, b}) >>> 16;
        end
    endfunction
    
    // Fixed-point square root
    function automatic [31:0] fp_sqrt;
        input [63:0] n;
        reg [63:0] t, q, b, r;
        integer i;
        begin
            t = 64'h8000000000000000;
            q = 64'h0;
            r = n;
            for (i = 0; i < 32; i = i + 1) begin
                b = q | t;
                q = q >> 1;
                if (r >= b) begin
                    r = r - b;
                    q = q | t;
                end
                t = t >> 2;
            end
            fp_sqrt = q[31:0];
        end
    endfunction
    
    // Distance calculation
    function automatic [63:0] calc_distance;
        input [31:0] x1, y1, x2, y2;
        reg [31:0] dx, dy;
        reg [63:0] dx_sq, dy_sq, sum_sq;
        begin
            dx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
            dy = (y1 > y2) ? (y1 - y2) : (y2 - y1);
            dx_sq = fp_mult(dx, dx);
            dy_sq = fp_mult(dy, dy);
            sum_sq = dx_sq + dy_sq;
            calc_distance = fp_sqrt(sum_sq);
        end
    endfunction
    
    // Savings calculation
    always @(*) begin
        for (integer i = 0; i < 8; i = i + 1) begin
            if (i < num_bottles) begin
                savings_adil[i] = dist_bin[i] - dist_adil[i];
                savings_bera[i] = dist_bin[i] - dist_bera[i];
            end else begin
                savings_adil[i] = 64'd0;
                savings_bera[i] = 64'd0;
            end
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 6'd0;
            bottle_idx <= 3'd0;
            total_distance <= 64'd0;
            done <= 1'b0;
            
            // Initialize arrays
            for (integer i = 0; i < 8; i = i + 1) begin
                dist_bin[i] <= 64'd0;
                dist_adil[i] <= 64'd0;
                dist_bera[i] <= 64'd0;
                best_idx[i] <= 3'd0;
                best_savings[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC_DIST;
                        counter <= 6'd0;
                        bottle_idx <= 3'd0;
                    end
                end
                
                CALC_DIST: begin
                    if (counter < num_bottles) begin
                        dist_bin[counter] <= calc_distance(tx, ty, bottle_x[counter], bottle_y[counter]);
                        dist_adil[counter] <= calc_distance(ax, ay, bottle_x[counter], bottle_y[counter]);
                        dist_bera[counter] <= calc_distance(bx, by, bottle_x[counter], bottle_y[counter]);
                        counter <= counter + 6'd1;
                    end else begin
                        counter <= 6'd0;
                        state <= FIND_SAVINGS;
                    end
                end
                
                FIND_SAVINGS: begin
                    if (counter < num_bottles) begin
                        // Track top 2 savings for Adil
                        if (counter == 0 || savings_adil[counter] > best_savings[0]) begin
                            best_savings[1] <= best_savings[0];
                            best_idx[1] <= best_idx[0];
                            best_savings[0] <= savings_adil[counter];
                            best_idx[0] <= counter;
                        end else if (savings_adil[counter] > best_savings[1]) begin
                            best_savings[1] <= savings_adil[counter];
                            best_idx[1] <= counter;
                        end
                        
                        // Track top 2 savings for Bera
                        if (counter == 0 || savings_bera[counter] > best_savings[0]) begin
                            best_savings[1] <= best_savings[0];
                            best_idx[1] <= best_idx[0];
                            best_savings[0] <= savings_bera[counter];
                            best_idx[1] <= counter;
                        end else if (savings_bera[counter] > best_savings[1]) begin
                            best_savings[1] <= savings_bera[counter];
                            best_idx[1] <= counter;
                        end
                        
                        counter <= counter + 6'd1;
                    end else begin
                        counter <= 6'd0;
                        state <= COMPUTE_RESULT;
                    end
                end
                
                COMPUTE_RESULT: begin
                    // Calculate total distance
                    total_distance <= (dist_bin[0] + dist_bin[1] + dist_bin[2] + dist_bin[3] +
                                     dist_bin[4] + dist_bin[5] + dist_bin[6] + dist_bin[7]) -
                                    (best_savings[0] + best_savings[1]);
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule