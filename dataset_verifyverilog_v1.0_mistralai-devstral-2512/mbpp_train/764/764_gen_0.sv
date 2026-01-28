module digit_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_data [15:0],
    input wire [15:0] str_valid,
    output reg [7:0] result,
    output reg done
);

    reg [7:0] result_next;
    reg done_next;

    // Combinational logic for digit counting
    always @(*) begin
        integer i;
        reg [7:0] count = 8'd0;
        
        // Check each character position
        for (i = 0; i < 16; i = i + 1) begin
            if (str_valid[i] && (str_data[i] >= 8'h30) && (str_data[i] <= 8'h39)) begin
                count = count + 8'd1;
            end
        end
        
        result_next = count;
        done_next = 1'b1;
    end

    // Sequential logic for output registration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
        end else if (start) begin
            result <= result_next;
            done <= done_next;
        end else begin
            done <= 1'b0;
        end
    end

endmodule