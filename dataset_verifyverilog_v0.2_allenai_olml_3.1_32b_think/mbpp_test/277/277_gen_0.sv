module dict_filter(input clk, input rst_n, input start, input [7:0] threshold, input [3:0] num_entries, input [3:0] key_0, input [3:0] key_1, input [3:0] key_2, input [3:0] key_3, input [7:0] val_0, input [7:0] val_1, input [7:0] val_2, input [7:0] val_3, output reg [59:0] result, output reg done);

// Registered inputs
reg [7:0] reg_threshold;
reg [3:0] reg_num_entries;
reg [3:0] reg_key_0, reg_key_1, reg_key_2, reg_key_3;
reg [7:0] reg_val_0, reg_val_1, reg_val_2, reg_val_3;

// State machine
parameter IDLE = 2'b00;
parameter COMPARE = 2'b01;
parameter DONE = 2'b10;
reg [1:0] state;
reg [2:0] compare_count;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        compare_count <= 0;
        reg_threshold <= threshold;
        reg_num_entries <= num_entries;
        reg_key_0 <= key_0; reg_key_1 <= key_1; reg_key_2 <= key_2; reg_key_3 <= key_3;
        reg_val_0 <= val_0; reg_val_1 <= val_1; reg_val_2 <= val_2; reg_val_3 <= val_3;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    reg_threshold <= threshold;
                    reg_num_entries <= num_entries;
                    reg_key_0 <= key_0; reg_key_1 <= key_1; reg_key_2 <= key_2; reg_key_3 <= key_3;
                    reg_val_0 <= val_0; reg_val_1 <= val_1; reg_val_2 <= val_2; reg_val_3 <= val_3;
                    state <= COMPARE;
                    compare_count <=0;
                end else begin
                    state <= IDLE;
                end
            end
            COMPARE: begin
                if (compare_count < 3) begin
                    compare_count <= compare_count + 1;
                    state <= COMPARE;
                end else if (compare_count == 3) begin
                    // Compute valid for each entry
                    reg [3:0] valid;
                    valid[0] = (0 < reg_num_entries) ? (reg_val_0 >= reg_threshold) : 0;
                    valid[1] = (1 < reg_num_entries) ? (reg_val_1 >= reg_threshold) : 0;
                    valid[2] = (2 < reg_num_entries) ? (reg_val_2 >= reg_threshold) : 0;
                    valid[3] = (3 < reg_num_entries) ? (reg_val_3 >= reg_threshold) : 0;

                    // Count valid entries
                    integer count = valid[0] + valid[1] + valid[2] + valid[3];

                    // Build packed_value (52 bits)
                    reg [51:0] packed_value;
                    packed_value = { 
                        {count, 
                         valid[3] ? {reg_key_3, reg_val_3} : {4'b0, 8'b0}, 
                         valid[2] ? {reg_key_2, reg_val_2} : {4'b0, 8'b0}, 
                         valid[1] ? {reg_key_1, reg_val_1} : {4'b0, 8'b0}, 
                         valid[0] ? {reg_key_0, reg_val_0} : {4'b0, 8'b0} 
                        }
                    };

                    // Assign to result with padding
                    result <= {7{1'b0}, packed_value}; // 59 bits total

                    // Move to next state after one more cycle
                    compare_count <= 4;
                    state <= COMPARE;
                end else begin // compare_count ==4
                    state <= DONE;
                end
            end
            DONE: state <= DONE;
        endcase
    end
end

// done output
assign done = (state == DONE);

endmodule