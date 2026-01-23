module string_formatter(input clk, input rst_n, input start, input [7:0] list_data [0:7], input [2:0] list_length, output reg [7:0] result_strings [0:7][0:4], output reg done, output reg [2:0] valid_count);

// Registers
reg [2:0] process_counter;
reg [2:0] valid_count_reg;
reg done_reg;
reg [7:0] local_result_strings [0:7][0:4];
reg start_triggered;
reg [2:0] initial_list_length;
reg [1:0] state;

// Default assignments for synthesis
assign result_strings = local_result_strings;
assign done = done_reg;
assign valid_count = valid_count_reg;

// Reset and start handling
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'd0;
        process_counter <= 3'd0;
        valid_count_reg <= 3'd0;
        done_reg <= 1'b0;
        start_triggered <= 1'b0;
        initial_list_length <= 3'd0;
        local_result_strings <= {{8{{5{{8'b0}}}}}};
    end else begin
        if (start) begin
            if (!start_triggered) begin
                start_triggered <= 1'b1;
                state <= 2'd1;
                process_counter <= 3'd0;
                initial_list_length <= list_length;
                valid_count_reg <= 3'd0;
                done_reg <= 1'b0;
            end
        end else begin
            start_triggered <= 1'b0;
        end
    end
end

// State machine
always_ff @(posedge clk) begin
    case(state)
        2'd1: begin // PROCESSING
            if (process_counter < 8) begin
                process_counter <= process_counter + 1;
                if (process_counter - 1 < initial_list_length) begin
                    local_result_strings[process_counter - 1] <= {{8'b01110100, 8'b01100101, 8'b01101101, 8'b01110000, list_data[process_counter - 1]}};
                end
            end else begin
                state <= 2'd2;
                done_reg <= 1'b1;
                valid_count_reg <= initial_list_length;
                process_counter <= 3'd0;
            end
        end
        2'd2: begin // DONE
            // Remain in DONE state
        end
    endcase
end

endmodule