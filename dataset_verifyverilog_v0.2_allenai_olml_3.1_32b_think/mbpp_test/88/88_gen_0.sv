module freq_counter (input clk, input rst_n, input start, input [6:0] list_data [0:15], output reg [6:0] unique_values [0:7], output reg [3:0] frequencies [0:7], output reg [3:0] unique_count, output reg done);
parameter IDLE = 2'd0, COLLECT_UNIQUE = 2'd1, COUNT_FREQ = 2'd2, DONE_STATE = 2'd3;
reg [1:2] state;
reg [3:0] element_idx_col;
reg [2:0] current_unique_idx;
reg [3:0] element_idx_count;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        unique_count <= 4'd0;
        done <= 1'b0;
        unique_values <= {8{8'hFF}};
        frequencies <= {8{4'h0}};
        element_idx_col <= 4'd0;
        current_unique_idx <= 3'd0;
        element_idx_count <= 4'd0;
    end else begin
        done <= done || (state == DONE_STATE);
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COLLECT_UNIQUE;
                end else begin
                    state <= IDLE;
                end
            end
            COLLECT_UNIQUE: begin
                if (element_idx_col < 16) begin
                    input_val = list_data[element_idx_col];
                    if (input_val != 8'hFF) begin
                        if (unique_count == 4'd0) begin
                            unique_values[0] <= input_val;
                            unique_count <= 4'd1;
                        end else if (unique_count ==4'd1) begin
                            if (unique_values[0] != input_val) begin
                                unique_values[1] <= input_val;
                                unique_count <=4'd2;
                            end
                        end else if (unique_count ==4'd2) begin
                            if (unique_values[0] != input_val && unique_values[1] != input_val) begin
                                unique_values[2] <= input_val;
                                unique_count <=4'd3;
                            end
                        end else if (unique_count ==4'd3) begin
                            if (unique_values[0] != input_val && unique_values[1] != input_val && unique_values[2] != input_val) begin
                                unique_values[3] <= input_val;
                                unique_count <=4'd4;
                            end
                        end else if (unique_count ==4'd4) begin
                            if (unique_values[0] != input_val && unique_values[1] != input_val && unique_values[2] != input_val && unique_values[3] != input_val) begin
                                unique_values[4] <= input_val;
                                unique_count <=4'd5;
                            end
                        end else if (unique_count ==4'd5) begin
                            if (unique_values[0] != input_val && unique_values[1] != input_val && unique_values[2] != input_val && 
                                unique_values[3] != input_val && unique_values[4] != input_val) begin
                                unique_values[5] <= input_val;
                                unique_count <=4'd6;
                            end
                        end else if (unique_count ==4'd6) begin
                            if (unique_values[0] != input_val && unique_values[1] != input_val && unique_values[2] != input_val && 
                                unique_values[3] != input_val && unique_values[4] != input_val && unique_values[5] != input_val) begin
                                unique_values[6] <= input_val;
                                unique_count <=4'd7;
                            end
                        end else if (unique_count ==4'd7) begin
                            if (unique_values[0] != input_val && unique_values[1] != input_val && unique_values[2] != input_val && 
                                unique_values[3] != input_val && unique_values[4] != input_val && unique_values[5] != input_val && 
                                unique_values[6] != input_val) begin
                                unique_values[7] <= input_val;
                                unique_count <=4'd8;
                            end
                        end
                    end // end if input_val !=8'hFF
                end // end if element_idx_col <16
                element_idx_col <= element_idx_col +1;
                if (element_idx_col >15) begin
                    state <= COUNT_FREQ;
                end else begin
                    state <= COLLECT_UNIQUE;
                end
            end
            COUNT_FREQ: begin
                if (unique_count ==4'd0) begin
                    state <= DONE_STATE;
                end else begin
                    if (current_unique_idx < unique_count) begin
                        if (element_idx_count <16) begin
                            current_val = unique_values[current_unique_idx];
                            current_data = list_data[element_idx_count];
                            if (current_data !=8'hFF && current_data == current_val) begin
                                frequencies[current_unique_idx] <= frequencies[current_unique_idx] +1;
                            end
                            element_idx_count <= element_idx_count +1;
                            state <= COUNT_FREQ;
                        end else begin
                            element_idx_count <=4'd0;
                            current_unique_idx <= current_unique_idx +1;
                            if (current_unique_idx < unique_count) begin
                                state <= COUNT_FREQ;
                            end else begin
                                state <= DONE_STATE;
                            end
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end
            end
            DONE_STATE: begin
                state <= IDLE;
            end
        endcase
    end
endmodule