module strlen (
    input clk,
    input rst_n,
    input start,
    input [127:0] string_data,
    output reg [3:0] length,
    output reg done
);

localparam IDLE = 2'b00;
localparam SCANNING = 2'b01;
localparam DONE = 2'b10;

reg [2:0] state;
reg [3:0] scan_counter;
reg [3:0] length_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        scan_counter <= 4'b0;
        length_reg <= 4'b0;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= SCANNING;
                scan_counter <= 4'b0;
                length_reg <= 4'b0;
            end
        end else if (state == SCANNING) begin
            if (scan_counter == 4'd15) begin
                state <= DONE;
                done <= 1'b0;
                if (length_reg == 4'd0) begin
                    length_reg <= 4'd15;
                end
            end else begin
                byte_value = string_data[(scan_counter * 8 + 7):scan_counter * 8];
                if (byte_value == 4'd0 && length_reg == 4'd0) begin
                    length_reg <= scan_counter;
                end
                scan_counter <= scan_counter + 1;
                done <= 1'b0;
            end
        end else if (state == DONE) begin
            done <= 1'b1;
        end
    end
end

assign length = length_reg;

endmodule