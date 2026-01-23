module min_diff (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [2:0] index,
    input data_valid,
    output reg [7:0] min_diff,
    output reg done,
    output reg [2:0] state_out
);

reg [7:0] arr [0:7];
reg [2:0] state, next_state;
reg [7:0] min_diff_reg;
reg done_reg;
reg [2:0] state_out_reg;
reg [3:0] data_count =0;
reg [2:0] outer_count =0;
reg [2:0] inner_count =0;
reg [3:0] diff_counter =0;
reg [7:0] temp;

localparam IDLE = 3'd0;
localparam LOAD = 3'd1;
localparam SORT = 3'd2;
localparam SORT_PASS = 3'd3;
localparam COMPARE = 3'd4;
localparam DONE = 3'd5;

always @(*) begin
    min_diff_reg <= 8'd0;
    done_reg <= 1'b0;
    state_out_reg <= IDLE;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        data_count <=0;
        outer_count <=0;
        inner_count <=0;
        diff_counter <=0;
        min_diff_reg <=0;
        done_reg <=0;
        state_out_reg <= IDLE;
        arr <=8'd0;
    end else begin
        state <= next_state;
        state_out_reg <= state;
        case (state)
            IDLE:  
                if (data_count ==8 && start) begin
                    next_state = SORT;
                end else begin
                    next_state = IDLE;
                end
            LOAD:  
                if (data_valid && index >=0 && index <=7) begin
                    arr[index] <= data_in;
                    data_count <= data_count +1;
                end
                if (data_count ==8 && start) begin
                    next_state = SORT;
                    outer_count <=0;
                    inner_count <=0;
                end else begin
                    next_state = LOAD;
                end
            SORT:  
                if (outer_count <7) begin
                    next_state = SORT_PASS;
                end else begin
                    next_state = COMPARE;
                end
            SORT_PASS:  
                if (inner_count < (7 - outer_count)) begin
                    if (arr[inner_count] > arr[inner_count+1]) begin
                        temp = arr[inner_count];
                        arr[inner_count] = arr[inner_count+1];
                        arr[inner_count+1] = temp;
                    end
                    inner_count <= inner_count +1;
                    next_state = SORT_PASS;
                end else begin
                    outer_count <= outer_count +1;
                    if (outer_count <7) begin
                        inner_count <=0;
                        next_state = SORT_PASS;
                    end else begin
                        next_state = COMPARE;
                    end
                end
            COMPARE:  
                if (diff_counter <7) begin
                    min_diff_reg <= (arr[diff_counter+1] - arr[diff_counter] < min_diff_reg) ? (arr[diff_counter+1] - arr[diff_counter]) : min_diff_reg;
                    diff_counter <= diff_counter +1;
                    next_state = COMPARE;
                end else begin
                    next_state = DONE;
                end
            DONE:  
                done_reg <= 1'b1;
                next_state = DONE;
        endcase
    end
end

assign min_diff = min_diff_reg;
assign done = done_reg;
assign state_out = state_out_reg;

endmodule