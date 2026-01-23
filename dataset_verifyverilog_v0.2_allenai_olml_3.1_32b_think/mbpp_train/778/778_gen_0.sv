module pack_duplicates (
    input clk,
    input rst_n,
    input start,
    input [3:0] length,
    input [15:0] data_in [0:15],
    output reg [3:0] group_starts [0:15],
    output reg [3:0] group_lengths [0:15],
    output reg [3:0] num_groups,
    output reg done
);

// Internal registers
reg [1:0] state;
reg [3:0] process_counter;
reg [3:0] current_group_start;
reg [3:0] current_group_length;
reg [3:0] num_groups_reg;
reg [15:0] group_starts_reg [0:15];
reg [3:0] group_lengths_reg [0:15];
reg [15:0] prev_data;
reg [3:0] prev_index;
reg [3:0] next_group_idx;
reg done_reg;

// Initialize registers on reset
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        process_counter <= 4'd0;
        current_group_start <= 4'd0;
        current_group_length <= 4'd0;
        num_groups_reg <= 4'd0;
        group_starts_reg[0] <=4'd0; group_starts_reg[1] <=4'd0; group_starts_reg[2] <=4'd0; group_starts_reg[3] <=4'd0;
        group_starts_reg[4] <=4'd0; group_starts_reg[5] <=4'd0; group_starts_reg[6] <=4'd0; group_starts_reg[7] <=4'd0;
        group_starts_reg[8] <=4'd0; group_starts_reg[9] <=4'd0; group_starts_reg[10] <=4'd0; group_starts_reg[11] <=4'd0;
        group_starts_reg[12] <=4'd0; group_starts_reg[13] <=4'd0; group_starts_reg[14] <=4'd0; group_starts_reg[15] <=4'd0;
        group_lengths_reg[0] <=4'd0; group_lengths_reg[1] <=4'd0; group_lengths_reg[2] <=4'd0; group_lengths_reg[3] <=4'd0;
        group_lengths_reg[4] <=4'd0; group_lengths_reg[5] <=4'd0; group_lengths_reg[6] <=4'd0; group_lengths_reg[7] <=4'd0;
        group_lengths_reg[8] <=4'd0; group_lengths_reg[9] <=4'd0; group_lengths_reg[10] <=4'd0; group_lengths_reg[11] <=4'd0;
        group_lengths_reg[12] <=4'd0; group_lengths_reg[13] <=4'd0; group_lengths_reg[14] <=4'd0; group_lengths_reg[15] <=4'd0;
        prev_data <= 16'd0;
        prev_index <= 4'd0;
        next_group_idx <= 4'd0;
        done_reg <=1'b0;
    end else if (state == 2'b00 && start) begin
        state <= 2'b01;
        process_counter <=4'd0;
        current_group_start <=4'd0;
        current_group_length <=4'd0;
        num_groups_reg <=4'd0;
        next_group_idx <=4'd0;
        prev_data <=16'd0;
        prev_index <=4'd0;
    end
end

// Main state machine
always @(posedge clk) begin
    if (!rst_n) begin
    end else if (state == 2'b01) begin
        if (process_counter <4'd16) begin
            integer index;
            index = process_counter;
            if (index < length) begin
                if (index ==4'd0) begin
                    if (num_groups_reg ==4'd0) begin
                        num_groups_reg <= num_groups_reg +1;
                    end
                    current_group_start <= index;
                    current_group_length <=4'd1;
                    prev_data <= data_in[index];
                    prev_index <= index;
                end else begin
                    if (data_in[index] != data_in[index-1]) begin
                        if (num_groups_reg >4'd0) begin
                            group_starts_reg[next_group_idx] <= current_group_start;
                            group_lengths_reg[next_group_idx] <= current_group_length;
                            next_group_idx <= next_group_idx +1;
                        end
                        current_group_start <= index;
                        current_group_length <=4'd1;
                        prev_data <= data_in[index];
                        prev_index <= index;
                    end else begin
                        current_group_length <= current_group_length +1;
                        prev_data <= data_in[index];
                        prev_index <= index;
                    end
                end
            end // index < length
            process_counter <= process_counter +1;
            if (process_counter ==4'd15) begin
                state <=2'b10;
                done_reg <=1'b1;
            end
        end
    end else if (state ==2'b10) begin
        state <=2'b10;
        done_reg <=1'b1;
    end
end

// Output assignments
assign group_starts = group_starts_reg;
assign group_lengths = group_lengths_reg;
assign num_groups = num_groups_reg;
assign done = done_reg;

endmodule