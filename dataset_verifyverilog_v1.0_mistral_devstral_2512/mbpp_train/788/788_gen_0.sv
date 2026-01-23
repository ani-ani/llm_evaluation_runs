module new_tuple (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input array of strings: 8 elements, each 16 characters (128 bits)
    input wire [127:0] test_str_arr [0:7],
    input wire [2:0] input_len,  // Number of valid input strings (1-8)
    
    // Input string to append: 16 characters (128 bits)
    input wire [127:0] test_str,
    
    // Output array: input_len + 1 strings
    output reg [127:0] result_arr [0:8],
    output reg [3:0] output_len,  // = input_len + 1
    output reg done
);

// State machine for sequential processing
reg [2:0] state;
reg [2:0] idx;

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
        // Clear result array
        for (integer i = 0; i < 9; i = i + 1) begin
            result_arr[i] <= 128'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                idx <= 3'd0;
                if (start) begin
                    state <= COPY;
                    output_len <= input_len + 4'd1;
                end
            end
            
            COPY: begin
                if (idx < input_len) begin
                    result_arr[idx] <= test_str_arr[idx];
                    idx <= idx + 3'd1;
                end else begin
                    state <= APPEND;
                end
            end
            
            APPEND: begin
                result_arr[input_len] <= test_str;
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