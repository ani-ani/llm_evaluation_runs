module subset_sum_calculator #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 32,
    parameter MOD = 1000000007
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr_0,
    input wire [DATA_WIDTH-1:0] arr_1,
    input wire [DATA_WIDTH-1:0] arr_2,
    input wire [DATA_WIDTH-1:0] arr_3,
    input wire [DATA_WIDTH-1:0] arr_4,
    input wire [DATA_WIDTH-1:0] arr_5,
    input wire [DATA_WIDTH-1:0] arr_6,
    input wire [DATA_WIDTH-1:0] arr_7,
    input wire [3:0] len,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] FINISH = 2'd2;

// Registers
reg [1:0] state;
reg [3:0] i;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd100;

// Power lookup table: pow_minus_one[k] = (2^k - 1) % MOD for k = 0 to MAX_N
reg [DATA_WIDTH-1:0] pow_minus_one [0:MAX_N];

integer k;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k = 0; k < MAX_N; k = k + 1) begin
            pow_minus_one[k] <= 32'd0;
        end
    end else begin
        pow_minus_one[0] <= 32'd0;   // 2^0 - 1
        pow_minus_one[1] <= 32'd1;   // 2^1 - 1
        pow_minus_one[2] <= 32'd3;   // 2^2 - 1
        pow_minus_one[3] <= 32'd7;   // 2^3 - 1
        pow_minus_one[4] <= 32'd15;  // 2^4 - 1
        pow_minus_one[5] <= 32'd31;  // 2^5 - 1
        pow_minus_one[6] <= 32'd63;  // 2^6 - 1
        pow_minus_one[7] <= 32'd127; // 2^7 - 1
        pow_minus_one[8] <= 32'd255; // 2^8 - 1
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 4'd0;
        result <= 32'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= COMPUTE;
                    i <= 4'd0;
                    result <= 32'd0;
                end
            end
            
            COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Calculate term
                reg [DATA_WIDTH-1:0] gap;
                reg [DATA_WIDTH-1:0] left;
                reg [DATA_WIDTH-1:0] right;
                reg [DATA_WIDTH-1:0] term;
                
                if (i < len - 1) begin
                    case (i)
                        4'd0: gap = arr_1 - arr_0;
                        4'd1: gap = arr_2 - arr_1;
                        4'd2: gap = arr_3 - arr_2;
                        4'd3: gap = arr_4 - arr_3;
                        4'd4: gap = arr_5 - arr_4;
                        4'd5: gap = arr_6 - arr_5;
                        4'd6: gap = arr_7 - arr_6;
                        default: gap = 32'd0;
                    endcase
                    
                    left = pow_minus_one[i+1];
                    right = pow_minus_one[len - i - 1];
                    
                    reg [63:0] term_mult1 = (gap % MOD) * (left % MOD);
                    reg [63:0] term_mult2 = (term_mult1 % MOD) * (right % MOD);
                    term = term_mult2 % MOD;
                    
                    result = (result + term) % MOD;
                    
                    if (i < len - 2) begin
                        i = i + 4'd1;
                    end else begin
                        state = FINISH;
                    end
                end else begin
                    state = FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule