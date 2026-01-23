module next_smallest (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_elements,
    input [7:0] data_in,
    input data_valid,
    output reg [7:0] result,
    output reg done,
    output reg valid
);

parameter IDLE = 3'd0, COLLECT=3'd1, PROCESS=3'd2, DONE=3'd3;
reg [2:0] state, num_to_collect, count;
reg [7:0] data_array [7:0];
reg [2:0] unique_count;
reg [7:0] min1, min2;
reg done, valid;

always @(negedge rst_n) begin
    state <= IDLE; num_to_collect <=3'd0; count <=3'd0;
    data_array <= {8{8'd0}}; unique_count <=3'd0;
    min1 <=8'd0; min2 <=8'd0; done <=1'b0; valid <=1'b0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        case (state)
            IDLE: if (start) begin
                num_to_collect <= num_elements; count <=3'd0; data_array <= {8{8'd0}};
                state <= COLLECT; end
            COLLECT: if (data_valid) begin
                data_array[count] <= data_in; count <= count +1;
                if (count == num_to_collect) state <= PROCESS; end
            PROCESS: begin
                if (num_to_collect <2) begin
                    result <=8'd255; done<=1'b1; valid<=1'b1; state<=DONE; end
                else begin
                    min1 <= data_array[0]; min2 <= data_array[1];
                    if (min1 > min2) begin min1 <= min2; min2 <= data_array[0]; end
                    if (num_to_collect >2) begin
                        if (data_array[2] < min1) begin min2 <= min1; min1 <= data_array[2]; end
                        else if (data_array[2] < min2) min2 <= data_array[2];
                    end
                    if (num_to_collect >3) begin
                        if (data_array[3] < min1) begin min2 <= min1; min1 <= data_array[3]; end
                        else if (data_array[3] < min2) min2 <= data_array[3];
                    end
                    if (num_to_collect >4) begin
                        if (data_array[4] < min1) begin min2 <= min1; min1 <= data_array[4]; end
                        else if (data_array[4] < min2) min2 <= data_array[4];
                    end
                    if (num_to_collect >5) begin
                        if (data_array[5] < min1) begin min2 <= min1; min1 <= data_array[5]; end
                        else if (data_array[5] < min2) min2 <= data_array[5];
                    end
                    if (num_to_collect >6) begin
                        if (data_array[6] < min1) begin min2 <= min1; min1 <= data_array[6]; end
                        else if (data_array[6] < min2) min2 <= data_array[6];
                    end
                    if (num_to_collect >7) begin
                        if (data_array[7] < min1) begin min2 <= min1; min1 <= data_array[7]; end
                        else if (data_array[7] < min2) min2 <= data_array[7];
                    end
                    result <= min2; done<=1'b1; valid<=1'b1; state<=DONE;
                end
            end
            DONE: ; 
        endcase
    end
end

// Outputs
assign result = result; assign done = done; assign valid = valid;
endmodule