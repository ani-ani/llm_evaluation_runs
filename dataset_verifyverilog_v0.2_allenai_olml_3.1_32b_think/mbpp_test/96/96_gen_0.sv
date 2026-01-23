module divisor_counter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] n,
    output reg [7:0] divisor_count,
    output reg done
);

reg [1:0] state;
reg [7:0] n_value;
reg [7:0] counter;
reg [7:0] internal_divisor_count;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        n_value <= 8'b0;
        counter <= 8'b0;
        internal_divisor_count <= 8'b0;
        done <= 1'b0;
    end else begin
        if (state == 2'b00) begin // IDLE
            if (start) begin
                state <= 2'b01;
                n_value <= n;
                counter <= 8'b1;
                internal_divisor_count <= 8'b0;
            end
            done <= 1'b0;
        end else if (state == 2'b01) begin // PROCESSING
            if (counter > n_value) begin
                state <= 2'b10;
                done <= 1'b1;
            end else begin
                if (n_value % counter == 0) begin
                    internal_divisor_count <= internal_divisor_count + 1;
                end
                counter <= counter + 1;
                done <= 1'b0;
            end
        end else if (state == 2'b10) begin // DONE
            done <= 1'b1;
        end
    end
end

assign divisor_count = internal_divisor_count;

endmodule