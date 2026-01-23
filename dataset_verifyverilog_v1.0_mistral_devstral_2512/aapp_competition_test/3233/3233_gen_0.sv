module scary_subarrays (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] packed_arr,
    input wire [3:0] n,
    output reg [5:0] result,
    output reg done
);

// Unpack 8x8-bit array from packed input
wire [7:0] arr [0:7];
assign arr[0] = packed_arr[7:0];
assign arr[1] = packed_arr[15:8];
assign arr[2] = packed_arr[23:16];
assign arr[3] = packed_arr[31:24];
assign arr[4] = packed_arr[39:32];
assign arr[5] = packed_arr[47:40];
assign arr[6] = packed_arr[55:48];
assign arr[7] = packed_arr[63:56];

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT_L = 3'd1;
localparam [2:0] CHECK_R = 3'd2;
localparam [2:0] COMPARE = 3'd3;
localparam [2:0] CHECK_ODD = 3'd4;
localparam [2:0] INCREMENT_R = 3'd5;
localparam [2:0] INCREMENT_L = 3'd6;
localparam [2:0] DONE = 3'd7;

// Registers
reg [2:0] state;
reg [2:0] l;
reg [2:0] r;
reg [2:0] count_less;
reg [5:0] result_reg;
reg [7:0] temp_arr_l;

// Combinational signals
wire [2:0] diff = r - l;
wire diff_even = ~diff[0];  // 1 if (r-l) even → length odd
wire [2:0] target_count = diff >> 1;  // (r-l)/2

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        l <= 3'd0;
        r <= 3'd0;
        count_less <= 3'd0;
        result_reg <= 6'd0;
        temp_arr_l <= 8'd0;
        done <= 1'b0;
    end else begin
        done <= 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INIT_L;
                    result_reg <= 6'd0;
                end
            end
            
            INIT_L: begin
                l <= 3'd0;
                temp_arr_l <= arr[0];
                count_less <= 3'd0;
                r <= 3'd0;
                state <= CHECK_R;
            end
            
            CHECK_R: begin
                if (r < n) begin
                    state <= COMPARE;
                end else begin
                    state <= INCREMENT_L;
                end
            end
            
            COMPARE: begin
                if (arr[r] < temp_arr_l) begin
                    count_less <= count_less + 1;
                end
                state <= CHECK_ODD;
            end
            
            CHECK_ODD: begin
                if (diff_even && (count_less == target_count)) begin
                    result_reg <= result_reg + 1;
                end
                state <= INCREMENT_R;
            end
            
            INCREMENT_R: begin
                r <= r + 1;
                state <= CHECK_R;
            end
            
            INCREMENT_L: begin
                l <= l + 1;
                if (l + 1 < n) begin
                    temp_arr_l <= arr[l + 1];
                    count_less <= 3'd0;
                    r <= l + 1;
                    state <= CHECK_R;
                end else begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                result <= result_reg;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule