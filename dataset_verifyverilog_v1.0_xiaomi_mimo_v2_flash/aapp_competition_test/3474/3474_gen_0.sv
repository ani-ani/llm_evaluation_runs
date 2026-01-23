module laser_tag #(
    parameter WIDTH = 32,
    parameter FRAC_BITS = 16
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] x1, y1, x2, y2, x3, y3,
    output reg [WIDTH-1:0] low_y,
    output reg [WIDTH-1:0] high_y,
    output reg low_inf,
    output reg high_inf,
    output reg can_hit,
    output reg done
);
    // State definitions
    localparam [4:0] IDLE            = 5'd0;
    localparam [4:0] COMPUTE_A_B     = 5'd1;
    localparam [4:0] COMPUTE_C       = 5'd2;
    localparam [4:0] COMPUTE_D       = 5'd3;
    localparam [4:0] COMPUTE_DENOM   = 5'd4;
    localparam [4:0] COMPUTE_S_PRIME = 5'd5;
    localparam [4:0] CHECK_CAN_HIT   = 5'd6;
    localparam [4:0] COMPUTE_ENDPOINT1 = 5'd7;
    localparam [4:0] COMPUTE_ENDPOINT2 = 5'd8;
    localparam [4:0] DETERMINE_RESULT  = 5'd9;
    localparam [4:0] DONE_STATE       = 5'd10;

    reg [4:0] state;
    reg [4:0] next_state;
    
    // Internal registers
    reg [WIDTH-1:0] A, B, C, D, denom;
    reg [WIDTH-1:0] Sx, Sy;
    reg [WIDTH-1:0] x_min, x_max;
    reg [WIDTH-1:0] dx, dy;
    reg signed [WIDTH-1:0] t;
    reg [WIDTH-1:0] y_values [0:1];
    reg inf_flags [0:1];
    reg signed_flag [0:1];
    reg [1:0] endpoint_count;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // Fixed-point multiplication helper
    function [WIDTH-1:0] mult;
        input [WIDTH-1:0] a, b;
        begin
            mult = (a * b) >>> FRAC_BITS;
        end
    endfunction

    // Fixed-point division helper (simplified)
    function [WIDTH-1:0] divide;
        input [WIDTH-1:0] num, denom_in;
        begin
            if (denom_in != 0) begin
                divide = num / denom_in;
            end else begin
                divide = {WIDTH{1'b0}};
            end
        end
    endfunction

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_A_B;
                else next_state = IDLE;
            end
            COMPUTE_A_B: next_state = COMPUTE_C;
            COMPUTE_C: next_state = COMPUTE_D;
            COMPUTE_D: next_state = COMPUTE_DENOM;
            COMPUTE_DENOM: next_state = COMPUTE_S_PRIME;
            COMPUTE_S_PRIME: next_state = CHECK_CAN_HIT;
            CHECK_CAN_HIT: begin
                if (can_hit) begin
                    if (endpoint_count == 2'd0) next_state = COMPUTE_ENDPOINT1;
                    else next_state = COMPUTE_ENDPOINT2;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            COMPUTE_ENDPOINT1: begin
                if (endpoint_count == 2'd2) next_state = DETERMINE_RESULT;
                else next_state = CHECK_CAN_HIT;
            end
            COMPUTE_ENDPOINT2: begin
                if (endpoint_count == 2'd2) next_state = DETERMINE_RESULT;
                else next_state = CHECK_CAN_HIT;
            end
            DETERMINE_RESULT: next_state = DONE_STATE;
            DONE_STATE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            low_inf <= 1'b0;
            high_inf <= 1'b0;
            can_hit <= 1'b0;
            low_y <= {WIDTH{1'b0}};
            high_y <= {WIDTH{1'b0}};
            A <= {WIDTH{1'b0}};
            B <= {WIDTH{1'b0}};
            C <= {WIDTH{1'b0}};
            D <= {WIDTH{1'b0}};
            denom <= {WIDTH{1'b0}};
            Sx <= {WIDTH{1'b0}};
            Sy <= {WIDTH{1'b0}};
            x_min <= {WIDTH{1'b0}};
            x_max <= {WIDTH{1'b0}};
            dx <= {WIDTH{1'b0}};
            dy <= {WIDTH{1'b0}};
            t <= {WIDTH{1'b0}};
            y_values[0] <= {WIDTH{1'b0}};
            y_values[1] <= {WIDTH{1'b0}};
            inf_flags[0] <= 1'b0;
            inf_flags[1] <= 1'b0;
            signed_flag[0] <= 1'b0;
            signed_flag[1] <= 1'b0;
            endpoint_count <= 2'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    endpoint_count <= 2'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        x_min <= (x1 < x2) ? x1 : x2;
                        x_max <= (x1 > x2) ? x1 : x2;
                    end
                end
                
                COMPUTE_A_B: begin
                    A <= y2 - y1;
                    B <= x1 - x2;
                end
                
                COMPUTE_C: begin
                    C <= -(mult(A, x1) + mult(B, y1));
                end
                
                COMPUTE_D: begin
                    D <= mult(A, x3) + mult(B, y3) + C;
                end
                
                COMPUTE_DENOM: begin
                    denom <= mult(A, A) + mult(B, B);
                end
                
                COMPUTE_S_PRIME: begin
                    if (denom != 0) begin
                        Sx <= x3 - divide(2 * mult(A, D), denom);
                        Sy <= y3 - divide(2 * mult(B, D), denom);
                    end else begin
                        Sx <= 0;
                        Sy <= 0;
                    end
                end
                
                CHECK_CAN_HIT: begin
                    if ((Sx > 0 && x_min >= Sx) || (Sx < 0 && x_max <= Sx) || (Sx == 0)) begin
                        can_hit <= 1'b0;
                    end else begin
                        can_hit <= 1'b1;
                    end
                end
                
                COMPUTE_ENDPOINT1, COMPUTE_ENDPOINT2: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        can_hit <= 1'b0;
                    end else if (can_hit && endpoint_count < 2'd2) begin
                        if (state == COMPUTE_ENDPOINT1) begin
                            dx <= x1 - Sx;
                            dy <= y1 - Sy;
                        end else begin
                            dx <= x2 - Sx;
                            dy <= y2 - Sy;
                        end
                        
                        if (dx == 0) begin
                            inf_flags[endpoint_count] <= 1'b1;
                            signed_flag[endpoint_count] <= (dy > 0) ? 1'b1 : 1'b0;
                        end else begin
                            inf_flags[endpoint_count] <= 1'b0;
                            t <= divide(-Sx, dx);
                            y_values[endpoint_count] <= Sy + mult(t, dy);
                        end
                        endpoint_count <= endpoint_count + 2'd1;
                    end
                end
                
                DETERMINE_RESULT: begin
                    if (inf_flags[0] && inf_flags[1]) begin
                        low_inf <= signed_flag[0] ? 1'b0 : 1'b1;
                        high_inf <= signed_flag[1] ? 1'b1 : 1'b0;
                        low_y <= {WIDTH{1'b0}};
                        high_y <= {WIDTH{1'b0}};
                    end else if (inf_flags[0]) begin
                        low_inf <= 1'b1;
                        high_inf <= 1'b0;
                        low_y <= {WIDTH{1'b0}};
                        high_y <= y_values[1];
                    end else if (inf_flags[1]) begin
                        low_inf <= 1'b0;
                        high_inf <= 1'b1;
                        low_y <= y_values[0];
                        high_y <= {WIDTH{1'b0}};
                    end else begin
                        low_inf <= 1'b0;
                        high_inf <= 1'b0;
                        low_y <= (y_values[0] < y_values[1]) ? y_values[0] : y_values[1];
                        high_y <= (y_values[0] > y_values[1]) ? y_values[0] : y_values[1];
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule