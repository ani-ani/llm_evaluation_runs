module count_element_in_list (input clk, input rst_n, input start, input [7:0] target_element, input [3:0][3:0][7:0] sublists, output reg [1:0] result, output reg done);

// Internal signals
reg [1:0] count;
reg [1:0] state;
reg [2:0] process_count;

// Match signals for each sublist
wire [3:0] sublist0 = sublists[0];
wire match_0 = (sublist0[0] == target_element) || (sublist0[1] == target_element) || (sublist0[2] == target_element) || (sublist0[3] == target_element);

wire [3:0] sublist1 = sublists[1];
wire match_1 = (sublist1[0] == target_element) || (sublist1[1] == target_element) || (sublist1[2] == target_element) || (sublist1[3] == target_element);

wire [3:0] sublist2 = sublists[2];
wire match_2 = (sublist2[0] == target_element) || (sublist2[1] == target_element) || (sublist2[2] == target_element) || (sublist2[3] == target_element);

wire [3:0] sublist3 = sublists[3];
wire match_3 = (sublist3[0] == target_element) || (sublist3[1] == target_element) || (sublist3[2] == target_element) || (sublist3[3] == target_element);

// Match selection based on process_count
wire match_sublist;
always @(*) begin
    if (process_count == 0) match_sublist = match_0;
    else if (process_count == 1) match_sublist = match_1;
    else if (process_count == 2) match_sublist = match_2;
    else if (process_count == 3) match_sublist = match_3;
    else match_sublist = 1'b0;
end

// Output assignments
assign result = count;
assign done = (state == 2'b10);

// State machine and register updates
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 2'b00;
        state <= 2'b00;
        process_count <= 3'b000;
    end else begin
        // Update count if in processing and match found
        if (state == 2'b01) begin // PROCESSING state
            if (process_count < 4) begin
                process_count <= process_count + 1;
            end
            if (process_count < 4 && match_sublist) begin
                count <= count + 1;
            end
        end

        // State transitions
        case(state)
            2'b00: // IDLE
                if (start) begin
                    state <= 2'b01;
                    process_count <= 3'b000;
                end
            end
            2'b01: // PROCESSING
                if (process_count == 4) begin
                    state <= 2'b10;
                end
            end
            2'b10: // DONE
                if (start) begin
                    state <= 2'b01;
                    count <= 2'b00;
                    process_count <= 3'b000;
                end
            endcase
        endcase
    end
end

endmodule