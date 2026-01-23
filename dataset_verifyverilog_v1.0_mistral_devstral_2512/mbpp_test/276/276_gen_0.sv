module cylinder_volume (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,
    input wire [15:0] height,
    output reg [31:0] volume,
    output reg done
);

    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] CALC_R_SQ = 2'b01;
    localparam [1:0] CALC_VOL = 2'b10;
    localparam [1:0] FINISH = 2'b11;
    
    localparam [31:0] PI_FIXED = 32'd205887;
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    reg [31:0] r_squared;
    reg [31:0] r_squared_h;
    
    reg [31:0] mult_a;
    reg [31:0] mult_b;
    wire [63:0] mult_result;
    
    assign mult_result = mult_a * mult_b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            volume <= 32'd0;
            r_squared <= 32'd0;
            r_squared_h <= 32'd0;
            mult_a <= 32'd0;
            mult_b <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        mult_a <= {16'b0, radius};
                        mult_b <= {16'b0, radius};
                    end
                end
                
                CALC_R_SQ: begin
                    r_squared <= mult_result[47:16];
                    mult_a <= mult_result[47:16];
                    mult_b <= {16'b0, height};
                end
                
                CALC_VOL: begin
                    r_squared_h <= mult_result[47:16];
                end
                
                FINISH: begin
                    volume <= (r_squared_h * PI_FIXED) >> 16;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CALC_R_SQ;
            CALC_R_SQ: next_state = CALC_VOL;
            CALC_VOL: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule