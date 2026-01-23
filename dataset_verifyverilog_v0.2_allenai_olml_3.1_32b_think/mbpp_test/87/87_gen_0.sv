module merge_dictionaries_three (input clk, input rst_n, input start, input [7:0] dict1_keys [5:0], input [7:0] dict1_vals [5:0], input [7:0] dict2_keys [5:0], input [7:0] dict2_vals [5:0], input [7:0] dict3_keys [5:0], input [7:0] dict3_vals [5:0], output reg [7:0] merged_keys, output reg [7:0] merged_vals, output reg done);
reg [7:0] merged_keys_reg [5:0];
reg [7:0] merged_vals_reg [5:0];
reg [2:0] unique_count;
reg [2:0] entry_index;
reg [2:0] dict_index;
reg [1:0] state;
reg [5:0] current_entry;
reg [1:0] proc_count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        merged_keys_reg <= 'b0;
        merged_vals_reg <= 'b0;
        unique_count <= 3'd0;
        entry_index <= 3'd0;
        dict_index <= 2'd0;
        state <= 2'd0;
        current_entry <= 6'd0;
        proc_count <= 2'd0;
    end else begin
        case(state)
            2'd0: begin
                if (start) state <= 1'd1;
                else state <= 2'd0;
            end
            1'd1: begin
                if (proc_count <4) begin
                    proc_count <= proc_count +1;
                    current_entry <= current_entry +1;
                    if (dict1_keys[current_entry] !=8'b0 && unique_count<6) begin
                        merged_keys_reg[unique_count] <= dict1_keys[current_entry];
                        merged_vals_reg[unique_count] <= dict1_vals[current_entry];
                        unique_count <= unique_count +1;
                    end
                end else begin
                    state <= 1'd2;
                    dict_index <= 1'd1;
                    current_entry <=6'd0;
                    proc_count <=2'd0;
                end
            end
            1'd2: begin
                if (proc_count <4) begin
                    proc_count <= proc_count +1;
                    current_entry <= current_entry +1;
                    if (dict2_keys[current_entry] !=8'b0 && unique_count<6) begin
                        merged_keys_reg[unique_count] <= dict2_keys[current_entry];
                        merged_vals_reg[unique_count] <= dict2_vals[current_entry];
                        unique_count <= unique_count +1;
                    end
                end else begin
                    state <=1'd3;
                    dict_index <=1'd2;
                    current_entry <=6'd0;
                    proc_count <=2'd0;
                end
            end
            1'd3: begin
                if (proc_count <4) begin
                    proc_count <= proc_count +1;
                    current_entry <= current_entry +1;
                    if (dict3_keys[current_entry] !=8'b0 && unique_count<6) begin
                        merged_keys_reg[unique_count] <= dict3_keys[current_entry];
                        merged_vals_reg[unique_count] <= dict3_vals[current_entry];
                        unique_count <= unique_count +1;
                    end
                end else begin
                    state <=1'd4;
                    proc_count <=2'd0;
                end
            end
            1'd4: done <=1'b1;
        endcase
    end
end
assign merged_keys = merged_keys_reg;
assign merged_vals = merged_vals_reg;
endmodule