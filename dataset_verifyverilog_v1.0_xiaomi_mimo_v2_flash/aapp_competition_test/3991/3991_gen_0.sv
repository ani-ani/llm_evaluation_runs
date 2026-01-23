module subset_sum_calculator #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 32,
    parameter MOD = 1000000007
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:MAX_N-1],
    input wire [3:0] len,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'b00;
localparam [1:0] COMPUTE = 2'b01;
localparam [1:0] DONE = 2'b10;

// Registers
reg [1:0] state;
reg [3:0] i;
reg [DATA_WIDTH-1:0] result_reg;

// Power lookup table: pow_minus_one[k] = (2^k - 1) % MOD for k = 0 to MAX_N
reg [DATA_WIDTH-1:0] pow_minus_one [0:MAX_N];

// Combinational logic for term calculation (current gap contribution)
wire [DATA_WIDTH-1:0] gap;
wire [DATA_WIDTH-1:0] left;
wire [DATA_WIDTH-1:0] right;
wire [63:0] term_mult1;
wire [63:0] term_mult2;
wire [DATA_WIDTH-1:0] term;

// Initialize power lookup table
initial begin
    pow_minus_one[0] = 32'd0;   // 2^0 - 1
    pow_minus_one[1] = 32'd1;   // 2^1 - 1
    pow_minus_one[2] = 32'd3;   // 2^2 - 1
    pow_minus_one[3] = 32'd7;   // 2^3 - 1
    pow_minus_one[4] = 32'd15;  // 2^4 - 1
    pow_minus_one[5] = 32'd31;  // 2^5 - 1
    pow_minus_one[6] = 32'd63;  // 2^6 - 1
    pow_minus_one[7] = 32'd127; // 2^7 - 1
    pow_minus_one[8] = 32'd255; // 2^8 - 1
end

// Combinational logic for term calculation
assign gap = (i < len - 1) ? (arr[i+1] - arr[i]) : 32'd0;
assign left = (i < len - 1) ? pow_minus_one[i+1] : 32'd0;
assign right = (i < len - 1) ? pow_minus_one[len-i-1] : 32'd0;
assign term_mult1 = (gap % MOD) * (left % MOD);
assign term_mult2 = (term_mult1 % MOD) * (right % MOD);
assign term = term_mult2 % MOD;

// State register and next state logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 4'd0;
        result_reg <= 32'd0;
        done <= 1'b0;
    end else begin
        // Default assignments
        done <= 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COMPUTE;
                    i <= 4'd0;
                    result_reg <= 32'd0;
                end
            end
            
            COMPUTE: begin
                if (i < len - 1) begin
                    result_reg <= (result_reg + term) % MOD;
                    i <= i + 4'd1;
                end else begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
                i <= 4'd0;
                result_reg <= 32'd0;
            end
        endcase
    end
end

// Output assignment
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 32'd0;
    end else begin
        result <= result_reg;
    end
end

endmodule