module new_tuple (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input array of strings: 8 elements, each 16 characters (128 bits)
    input wire [127:0] test_str_arr_0,
    input wire [127:0] test_str_arr_1,
    input wire [127:0] test_str_arr_2,
    input wire [127:0] test_str_arr_3,
    input wire [127:0] test_str_arr_4,
    input wire [127:0] test_str_arr_5,
    input wire [127:0] test_str_arr_6,
    input wire [127:0] test_str_arr_7,
    input wire [2:0] input_len,  // Number of valid input strings (1-8)
    
    // Input string to append: 16 characters (128 bits)
    input wire [127:0] test_str,
    
    // Output array: input_len + 1 strings (max 9)
    output reg [127:0] result_arr_0,
    output reg [127:0] result_arr_1,
    output reg [127:0] result_arr_2,
    output reg [127:0] result_arr_3,
    output reg [127:0] result_arr_4,
    output reg [127:0] result_arr_5,
    output reg [127:0] result_arr_6,
    output reg [127:0] result_arr_7,
    output reg [127:0] result_arr_8,
    output reg [3:0] output_len,  // = input_len + 1
    output reg done
);

// State machine for sequential processing
reg [2:0] state;
reg [2:0] idx;
reg [2:0] input_len_reg;

localparam [2:0] IDLE = 3'd0;
localparam [2:0] COPY = 3'd1;
localparam [2:0] APPEND = 3'd2;
localparam [2:0] FINISH = 3'd3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        idx <= 3'd0;
        done <= 1'b0;
        output_len <= 4'd0;
        input_len_reg <= 3'd0;
        result_arr_0 <= 128'd0;
        result_arr_1 <= 128'd0;
        result_arr_2 <= 128'd0;
        result_arr_3 <= 128'd0;
        result_arr_4 <= 128'd0;
        result_arr_5 <= 128'd0;
        result_arr_6 <= 128'd0;
        result_arr_7 <= 128'd0;
        result_arr_8 <= 128'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                idx <= 3'd0;
                if (start) begin
                    state <= COPY;
                    input_len_reg <= input_len;
                    output_len <= {1'b0, input_len} + 4'd1;
                end
            end
            
            COPY: begin
                if (idx < input_len_reg) begin
                    case (idx)
                        3'd0: result_arr_0 <= test_str_arr_0;
                        3'd1: result_arr_1 <= test_str_arr_1;
                        3'd2: result_arr_2 <= test_str_arr_2;
                        3'd3: result_arr_3 <= test_str_arr_3;
                        3'd4: result_arr_4 <= test_str_arr_4;
                        3'd5: result_arr_5 <= test_str_arr_5;
                        3'd6: result_arr_6 <= test_str_arr_6;
                        3'd7: result_arr_7 <= test_str_arr_7;
                    endcase
                    idx <= idx + 3'd1;
                end else begin
                    state <= APPEND;
                end
            end
            
            APPEND: begin
                result_arr_8 <= test_str;
                state <= FINISH;
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