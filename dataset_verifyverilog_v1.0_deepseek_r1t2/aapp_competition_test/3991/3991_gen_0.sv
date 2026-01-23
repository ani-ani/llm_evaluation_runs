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
localparam [1:0] IDLE    = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] DONE_STATE = 2'd2;

// Registers
reg [1:0] state, next_state;
reg [3:0] i, next_i;
reg [DATA_WIDTH-1:0] next_result;
reg [7:0] cycle_count;

// Compute power values combinatorially
wire [DATA_WIDTH-1:0] gap = (i < len - 1) ? (arr[i+1] - arr[i]) : 32'd0;
wire [DATA_WIDTH-1:0] left_power = (i < len - 1) ? (32'd1 << (i + 1)) - 32'd1 : 32'd0;
wire [DATA_WIDTH-1:0] right_power = (i < len - 1) ? (32'd1 << (len - i - 1)) - 32'd1 : 32'd0;

// Intermediate calculations with MOD
wire [63:0] term_val1 = (gap % MOD) * (left_power % MOD);
wire [63:0] term_val2 = (term_val1 % MOD) * (right_power % MOD);
wire [DATA_WIDTH-1:0] term = term_val2 % MOD;

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 4'd0;
        result <= 32'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        state <= next_state;
        i <= next_i;
        result <= next_result;
        cycle_count <= (state == COMPUTE) ? cycle_count + 8'd1 : 8'd0;
        done <= (next_state == DONE_STATE);
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    next_i = i;
    next_result = result;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = COMPUTE;
                next_i = 4'd0;
                next_result = 32'd0;
            end
        end
        
        COMPUTE: begin
            if (cycle_count < MAX_N*2) begin
                if (i < len - 1) begin
                    next_result = (result + term) % MOD;
                    next_i = i + 4'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end else begin
                next_state = DONE_STATE; // Safety timeout
            end
        end
        
        DONE_STATE: begin
            if (!start) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule