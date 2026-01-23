module laser_tag #(
    parameter WIDTH = 32,
    parameter FRAC_BITS = 16
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] x1,
    input wire [WIDTH-1:0] y1,
    input wire [WIDTH-1:0] x2,
    input wire [WIDTH-1:0] y2,
    input wire [WIDTH-1:0] x3,
    input wire [WIDTH-1:0] y3,
    output reg [WIDTH-1:0] low_y,
    output reg [WIDTH-1:0] high_y,
    output reg low_inf,
    output reg high_inf,
    output reg can_hit,
    output reg done
);
    localparam [4:0] IDLE                = 5'd0;
    localparam [4:0] COMPUTE_A_B          = 5'd1;
    localparam [4:0] COMPUTE_C            = 5'd2;
    localparam [4:0] COMPUTE_D            = 5'd3;
    localparam [4:0] COMPUTE_DENOM        = 5'd4;
    localparam [4:0] COMPUTE_S_PRIME      = 5'd5;
    localparam [4:0] CHECK_CAN_HIT        = 5'd6;
    localparam [4:0] COMPUTE_ENDPOINT1    = 5'd7;
    localparam [4:0] COMPUTE_ENDPOINT2    = 5'd8;
    localparam [4:0] DETERMINE_RESULT     = 5'd9;
    localparam [4:0] DONE_STATE           = 5'd10;
    
    reg [4:0] state;
    reg [WIDTH-1:0] A, B, C, D, denom;
    reg [WIDTH-1:0] Sx, Sy;
    reg [WIDTH-1:0] x_min, x_max;
    reg [WIDTH-1:0] dx, dy, t;
    reg [1:0] endpoint_count;
    reg [WIDTH-1:0] y_values [0:1];
    reg inf_flags [0:1];
    reg signed_flag [0:1];
    integer i;
    
    function [WIDTH-1:0] mult;
        input [WIDTH-1:0] a, b;
        reg [2*WIDTH-1:0] temp;
        begin
            temp = a * b;
            mult = temp[(2*WIDTH-1)-FRAC_BITS -: WIDTH];
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            can_hit <= 1'b0;
            low_inf <= 1'b0;
            high_inf <= 1'b0;
            low_y <= {WIDTH{1'b0}};
            high_y <= {WIDTH{1'b0}};
            A <= {WIDTH{1'b0}};
            B <= {WIDTH{1'b0}};
            C <= {WIDTH{1'b0}};
            D <= {WIDTH{1'b0}};
            denom <= {WIDTH{1'b0}};
            Sx <= {WIDTH{1'b0}};
            Sy <= {WIDTH{1'b0}};
            dx <= {WIDTH{1'b0}};
            dy <= {WIDTH{1'b0}};
            t <= {WIDTH{1'b0}};
            for (i = 0; i < 2; i = i + 1) begin
                y_values[i] <= {WIDTH{1'b0}};
                inf_flags[i] <= 1'b0;
                signed_flag[i] <= 1'b0;
            end
            endpoint_count <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_min <= (x1 < x2) ? x1 : x2;
                        x_max <= (x1 > x2) ? x1 : x2;
                        endpoint_count <= 2'd0;
                        state <= COMPUTE_A_B;
                    end
                end
                
                COMPUTE_A_B: begin
                    A <= y2 - y1;
                    B <= x1 - x2;
                    state <= COMPUTE_C;
                end
                
                COMPUTE_C: begin
                    C <= -((mult(A, x1)) + (mult(B, y1)));
                    state <= COMPUTE_D;
                end
                
                COMPUTE_D: begin
                    D <= (mult(A, x3)) + (mult(B, y3)) + C;
                    state <= COMPUTE_DENOM;
                end
                
                COMPUTE_DENOM: begin
                    denom <= mult(A, A) + mult(B, B);
                    state <= COMPUTE_S_PRIME;
                end
                
                COMPUTE_S_PRIME: begin
                    if (denom != {WIDTH{1'b0}}) begin
                        Sx <= x3 - ((2 * mult(A, D)) / denom);
                        Sy <= y3 - ((2 * mult(B, D)) / denom);
                    end else begin
                        Sx <= x3;
                        Sy <= y3;
                    end
                    state <= CHECK_CAN_HIT;
                end
                
                CHECK_CAN_HIT: begin
                    if ((Sx > {WIDTH{1'b0}} && x_min >= Sx) || 
                        (Sx < {WIDTH{1'b0}} && x_max <= Sx) || 
                        (Sx == {WIDTH{1'b0}})) begin
                        can_hit <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        can_hit <= 1'b1;
                        state <= COMPUTE_ENDPOINT1;
                    end
                end
                
                COMPUTE_ENDPOINT1, COMPUTE_ENDPOINT2: begin
                    if (state == COMPUTE_ENDPOINT1) begin
                        dx <= x1 - Sx;
                        dy <= y1 - Sy;
                    end else begin
                        dx <= x2 - Sx;
                        dy <= y2 - Sy;
                    end
                    
                    if (dx == {WIDTH{1'b0}}) begin
                        inf_flags[endpoint_count] <= 1'b1;
                        signed_flag[endpoint_count] <= (dy > {WIDTH{1'b0}}) ? 1'b1 : 1'b0;
                        y_values[endpoint_count] <= {WIDTH{1'b0}};
                    end else begin
                        inf_flags[endpoint_count] <= 1'b0;
                        t <= (-Sx) / dx;
                        y_values[endpoint_count] <= Sy + mult(t, dy);
                    end
                    
                    if (state == COMPUTE_ENDPOINT1) begin
                        state <= COMPUTE_ENDPOINT2;
                    end else begin
                        state <= DETERMINE_RESULT;
                    end
                    endpoint_count <= endpoint_count + 2'd1;
                end
                
                DETERMINE_RESULT: begin
                    if (inf_flags[0] && inf_flags[1]) begin
                        low_inf  <= ~signed_flag[0];
                        high_inf <= signed_flag[1];
                        low_y    <= {WIDTH{1'b0}};
                        high_y   <= {WIDTH{1'b0}};
                    end else if (inf_flags[0]) begin
                        low_inf  <= 1'b1;
                        high_inf <= 1'b0;
                        low_y    <= {WIDTH{1'b0}};
                        high_y   <= y_values[1];
                    end else if (inf_flags[1]) begin
                        low_inf  <= 1'b0;
                        high_inf <= 1'b1;
                        low_y    <= y_values[0];
                        high_y   <= {WIDTH{1'b0}};
                    end else begin
                        low_inf  <= 1'b0;
                        high_inf <= 1'b0;
                        low_y    <= (y_values[0] < y_values[1]) ? y_values[0] : y_values[1];
                        high_y   <= (y_values[0] > y_values[1]) ? y_values[0] : y_values[1];
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule