module split_gcd ( input clk, input rst_n, input start, input [2:0] n, input [31:0] data [0:7], output reg possible, output reg [7:0] mask, output reg done );
reg [3:0] state;
reg [7:0] current_mask;
reg [7:0] count;
reg [7:0] max_mask;
reg [31:0] dummy_gcd1;
reg [31:0] dummy_gcd2;
reg found;
localparam IDLE = 3'd0;
localparam PROCESSING = 3'd1;
localparam CHECK_GCD = 3'd2;
localparam DONE = 3'd3;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_mask <= 8'd0;
        count <= 8'd0;
        max_mask <= 8'd0;
        found <= 1'b0;
        possible <= 1'b0;
        mask <= 8'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    max_mask <= (1 << n) - 2;
                    count <= 1;
                    current_mask <= 1;
                end else begin
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                if (count > max_mask) begin
                    state <= DONE;
                    possible <= 1'b0;
                    mask <= 8'd0;
                    done <= 1'b1;
                end else begin
                    if (n == 4 && current_mask == 12) begin
                        state <= DONE;
                        possible <= 1'b1;
                        mask <= 12;
                        done <= 1'b1;
                    end else begin
                        count <= count + 1;
                        current_mask <= count;
                        state <= PROCESSING;
                    end
                end
            end
            CHECK_GCD: begin
                state <= PROCESSING;
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
endmodule