module vault_security(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] A,
    input wire [3:0] B,
    input wire [3:0] L,
    output reg [15:0] insecure,
    output reg [15:0] secure,
    output reg [15:0] super_secure,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] COMPUTE = 3'd2;
localparam [2:0] INCR_J = 3'd3;
localparam [2:0] INCR_X = 3'd4;
localparam [2:0] DONE = 3'd5;

reg [2:0] state;
reg [3:0] x_reg;
reg [4:0] j_reg;
reg [15:0] cnt_ins;
reg [15:0] cnt_sec;
reg [15:0] cnt_sup;

// Helper function: check if two numbers are coprime
function automatic is_coprime;
    input [3:0] a, b;
    begin
        if (a == 0 || b == 0)
            is_coprime = (a == 0 && b == 0) ? 0 : (a == 0 ? (b == 1) : (b == 0 ? (a == 1) : 1));
        else begin
            if (a%2==0 && b%2==0) is_coprime = 0;
            else if (a%3==0 && b%3==0) is_coprime = 0;
            else if (a%5==0 && b%5==0) is_coprime = 0;
            else if (a%7==0 && b%7==0) is_coprime = 0;
            else if (a%11==0 && b%11==0) is_coprime = 0;
            else if (a%13==0 && b%13==0) is_coprime = 0;
            else is_coprime = 1;
        end
    end
endfunction

// Sequential state update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x_reg <= 4'd0;
        j_reg <= 5'd0;
        cnt_ins <= 16'd0;
        cnt_sec <= 16'd0;
        cnt_sup <= 16'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) state <= INIT;
            end
            
            INIT: begin
                x_reg <= 4'd1;
                j_reg <= 5'd0;
                cnt_ins <= 16'd0;
                cnt_sec <= 16'd0;
                cnt_sup <= 16'd0;
                state <= COMPUTE;
            end
            
            COMPUTE: begin
                reg cop1 = is_coprime(x_reg, j_reg);
                reg cop2 = is_coprime(x_reg, (A + B) - j_reg);
                
                if (cop1 && cop2) cnt_sup <= cnt_sup + 16'd1;
                else if (cop1 || cop2) cnt_sec <= cnt_sec + 16'd1;
                else cnt_ins <= cnt_ins + 16'd1;
                
                state <= INCR_J;
            end
            
            INCR_J: begin
                if (j_reg < (A + B)) begin
                    j_reg <= j_reg + 5'd1;
                    state <= COMPUTE;
                end else begin
                    j_reg <= 5'd0;
                    state <= INCR_X;
                end
            end
            
            INCR_X: begin
                if (x_reg < L) begin
                    x_reg <= x_reg + 4'd1;
                    state <= COMPUTE;
                end else begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule