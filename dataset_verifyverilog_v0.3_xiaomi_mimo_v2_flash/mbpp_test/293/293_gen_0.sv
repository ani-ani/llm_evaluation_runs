module pythagoras_third_side (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] w,
    input wire [15:0] h,
    output reg [31:0] result,
    output reg done
);

// Computes sqrt(w*w + h*h) using Q16.16 fixed-point format
// State machine for sequential computation
reg [2:0] state;
reg [31:0] sum_sq;
reg [31:0] root;
reg [31:0] remainder;
reg [5:0] counter;

localparam [2:0] IDLE = 3'd0;
localparam [2:0] MUL_W = 3'd1;
localparam [2:0] MUL_H = 3'd2;
localparam [2:0] SQRT_INIT = 3'd3;
localparam [2:0] SQRT_LOOP = 3'd4;
localparam [2:0] SCALE = 3'd5;
localparam [2:0] DONE_STATE = 3'd6;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        sum_sq <= 32'd0;
        root <= 32'd0;
        remainder <= 32'd0;
        counter <= 6'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // w * w (max 16x16 = 32 bits)
                    sum_sq <= w * w;
                    state <= MUL_W;
                end
            end
            
            MUL_W: begin
                // h * h
                sum_sq <= sum_sq + (h * h);
                state <= MUL_H;
            end
            
            MUL_H: begin
                // Initialize sqrt calculation
                root <= 32'd0;
                remainder <= 32'd0;
                counter <= 6'd31;  // 32-bit input
                state <= SQRT_INIT;
            end
            
            SQRT_INIT: begin
                // Start digit-by-digit sqrt
                state <= SQRT_LOOP;
            end
            
            SQRT_LOOP: begin
                if (counter > 0) begin
                    // Shift remainder left by 2 and add next 2 bits
                    remainder <= (remainder << 2) | ((sum_sq >> (counter * 2 - 2)) & 2'b11);
                    
                    // Test if root*4 + 1 <= remainder
                    if (remainder >= ((root << 2) | 1)) begin
                        remainder <= remainder - ((root << 2) | 1);
                        root <= (root << 1) | 1;
                    end else begin
                        root <= root << 1;
                    end
                    
                    counter <= counter - 1;
                end else begin
                    // Integer sqrt done, now scale to Q16.16
                    state <= SCALE;
                end
            end
            
            SCALE: begin
                // Convert to Q16.16: result = root * 65536
                result <= root << 16;
                state <= DONE_STATE;
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule