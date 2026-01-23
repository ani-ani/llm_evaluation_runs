module vault_security (
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
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] INIT    = 3'd1;
localparam [2:0] COMPUTE = 3'd2;
localparam [2:0] INCR_J  = 3'd3;
localparam [2:0] INCR_X  = 3'd4;
localparam [2:0] DONE    = 3'd5;

reg [2:0] state;
reg [2:0] next_state;
reg [3:0] x_reg;
reg [3:0] next_x_reg;
reg [4:0] j_reg;
reg [4:0] next_j_reg; // j from 0 to A+B (max 16)
reg [15:0] cnt_ins;
reg [15:0] next_cnt_ins;
reg [15:0] cnt_sec;
reg [15:0] next_cnt_sec;
reg [15:0] cnt_sup;
reg [15:0] next_cnt_sup;
reg [4:0] max_j;
reg [4:0] next_max_j;
reg cop1;
reg cop2;

// Helper function: check if two numbers are coprime (for numbers up to 16)
function automatic is_coprime(input [3:0] a, input [3:0] b);
    reg result;
    begin
        if (a == 4'd0 && b == 4'd0) begin
            result = 1'b0;
        end else if (a == 4'd0) begin
            result = (b == 4'd1);
        end else if (b == 4'd0) begin
            result = (a == 4'd1);
        end else begin
            // Check common prime factors: 2,3,5,7,11,13
            result = 1'b1;
            if (a[0] == 1'b0 && b[0] == 1'b0) result = 1'b0;
            else if ((a % 4'd3 == 4'd0) && (b % 4'd3 == 4'd0)) result = 1'b0;
            else if ((a % 4'd5 == 4'd0) && (b % 4'd5 == 4'd0)) result = 1'b0;
            else if ((a % 4'd7 == 4'd0) && (b % 4'd7 == 4'd0)) result = 1'b0;
            else if ((a % 4'd11 == 4'd0) && (b % 4'd11 == 4'd0)) result = 1'b0;
            else if ((a % 4'd13 == 4'd0) && (b % 4'd13 == 4'd0)) result = 1'b0;
        end
        is_coprime = result;
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
        max_j <= 5'd0;
        done <= 1'b0;
        insecure <= 16'd0;
        secure <= 16'd0;
        super_secure <= 16'd0;
    end else begin
        state <= next_state;
        x_reg <= next_x_reg;
        j_reg <= next_j_reg;
        cnt_ins <= next_cnt_ins;
        cnt_sec <= next_cnt_sec;
        cnt_sup <= next_cnt_sup;
        max_j <= next_max_j;
        if (state == DONE) begin
            insecure <= cnt_ins;
            secure <= cnt_sec;
            super_secure <= cnt_sup;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
end

// Combinational next state logic
always @(*) begin
    // Default assignments
    next_state = state;
    next_x_reg = x_reg;
    next_j_reg = j_reg;
    next_cnt_ins = cnt_ins;
    next_cnt_sec = cnt_sec;
    next_cnt_sup = cnt_sup;
    next_max_j = max_j;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            next_x_reg = 4'd1;
            next_j_reg = 5'd0;
            next_cnt_ins = 16'd0;
            next_cnt_sec = 16'd0;
            next_cnt_sup = 16'd0;
            next_max_j = {1'b0, A} + {1'b0, B};
            next_state = COMPUTE;
        end
        
        COMPUTE: begin
            // Compute coprime flags
            cop1 = is_coprime(x_reg, j_reg[3:0]);
            cop2 = is_coprime(x_reg, max_j[3:0] - j_reg[3:0]);
            
            if (cop1 && cop2) begin
                next_cnt_sup = cnt_sup + 16'd1;
            end else if (cop1 || cop2) begin
                next_cnt_sec = cnt_sec + 16'd1;
            end else begin
                next_cnt_ins = cnt_ins + 16'd1;
            end
            next_state = INCR_J;
        end
        
        INCR_J: begin
            if (j_reg < max_j) begin
                next_j_reg = j_reg + 5'd1;
                next_state = COMPUTE;
            end else begin
                next_j_reg = 5'd0;
                next_state = INCR_X;
            end
        end
        
        INCR_X: begin
            if (x_reg < L) begin
                next_x_reg = x_reg + 4'd1;
                next_state = COMPUTE;
            end else begin
                next_state = DONE;
            end
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule