module sort_numbers ( 
    input clk, 
    input rst_n, 
    input start, 
    input [319:0] input_str, 
    output reg [319:0] result, 
    output reg done 
);
reg [2:0] state, next_state;
reg [319:0] input_str_reg;
reg [7:0] parsed_words [7:0];
reg [2:0] word_count;
reg [7:0] sort_array [7:0];
reg [4:0] convert_buf [7:0];
reg [319:0] result_reg;
reg done_reg;
reg [15:0] state_counter;
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        state <= 0; 
        input_str_reg <= 0; 
        parsed_words <= 8'b0; 
        word_count <= 0; 
        sort_array <= 8'b0; 
        convert_buf <= 5'b0; 
        result_reg <= 0; 
        done_reg <= 0; 
        state_counter <= 0; 
    end else begin 
        state_counter <= state_counter + 1; 
        if (state == 0) begin // IDLE 
            if (start) begin 
                input_str_reg <= input_str; 
                state <= 1; // PARSE 
                state_counter <= 40; 
            end 
        end else if (state == 1) begin // PARSE 
            if (state_counter == 40) begin 
                state <= 2; // MAP 
                state_counter <= 8; 
            end 
        end else if (state == 2) begin // MAP 
            if (state_counter == 8) begin 
                state <= 3; // SORT 
                state_counter <= 64; 
            end 
        end else if (state == 3) begin // SORT 
            if (state_counter == 64) begin 
                state <= 4; // CONVERT 
                state_counter <= 8; 
            end 
        end else if (state == 4) begin // CONVERT 
            if (state_counter == 8) begin 
                state <= 5; // BUILD 
                state_counter <= 40; 
            end 
        end else if (state == 5) begin // BUILD 
            if (state_counter == 40) begin 
                state <= 6; // WAIT 
                state_counter <= 40; 
            end 
        end else if (state == 6) begin // WAIT 
            if (state_counter == 40) begin 
                state <= 7; // DONE 
                done_reg <= 1'b1; 
                result_reg <= input_str_reg; 
            end 
        end 
    end 
end
assign result = result_reg;
assign done = done_reg;
endmodule