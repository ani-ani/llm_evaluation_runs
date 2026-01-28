module max_subarray_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str_data,
    input wire [3:0] str_len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] char_index;
    reg signed [15:0] current_sum;
    reg signed [15:0] max_sum;
    reg [7:0] current_char;
    reg signed [15:0] weight;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_index <= 4'd0;
            current_sum <= 16'd0;
            max_sum <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    char_index = 4'd0;
                    current_sum = 16'd0;
                    max_sum = 16'd0;
                end
            end

            PROCESSING: begin
                if (char_index < str_len) begin
                    // Extract current character (8 bits)
                    current_char = str_data[(char_index * 8) +: 8];
                    
                    // Determine weight: '0'=+1, '1'=-1
                    if (current_char == 8'd49) // '1' is 0x31 = 49
                        weight = 16'd-1;
                    else
                        weight = 16'd1;
                    
                    // Update current_sum
                    current_sum = current_sum + weight;
                    
                    // Update max_sum
                    if (current_sum > max_sum)
                        max_sum = current_sum;
                    
                    // Reset current_sum if negative
                    if (current_sum < 16'd0)
                        current_sum = 16'd0;
                    
                    // Increment index
                    char_index = char_index + 4'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                result = max_sum;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule