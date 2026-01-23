module can_arrange (input clk, input rst_n, input start, input [3:0] length, input [15:0] arr [0:15], output reg [3:0] result, output reg done);
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [3:0] max_index;
reg [7:0] cycle_count;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        max_index <= 4'd0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    cycle_count <= 8'd0;
                    max_index <= 4'd0;
                end else begin
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                cycle_count <= cycle_count + 1;
                if (cycle_count < 18) begin
                    if (cycle_count >= 1 && cycle_count < length) begin
                        if (arr[cycle_count] < arr[cycle_count - 1]) begin
                            if (cycle_count > max_index) begin
                                max_index <= cycle_count;
                            end
                        end
                    end
                end else begin
                    state <= DONE;
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
end

assign result = (max_index == 4'd0) ? 4'd15 : max_index;
assign done = (state == DONE);

endmodule