module find_diff_first_even_odd (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] len,
    output reg [15:0] result,
    output reg done
);

    reg [2:0] index;
    reg [7:0] first_even;
    reg [7:0] first_odd;
    reg even_found;
    reg odd_found;
    reg processing;

    wire [7:0] current_val;
    assign current_val = (index == 3'd0) ? arr_0 :
                        (index == 3'd1) ? arr_1 :
                        (index == 3'd2) ? arr_2 :
                        (index == 3'd3) ? arr_3 :
                        (index == 3'd4) ? arr_4 :
                        (index == 3'd5) ? arr_5 :
                        (index == 3'd6) ? arr_6 :
                        arr_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'd0;
            index <= 3'd0;
            first_even <= 8'd0;
            first_odd <= 8'd0;
            even_found <= 1'b0;
            odd_found <= 1'b0;
            processing <= 1'b0;
        end else begin
            if (start && !processing) begin
                processing <= 1'b1;
                done <= 1'b0;
                index <= 3'd0;
                first_even <= 8'd0;
                first_odd <= 8'd0;
                even_found <= 1'b0;
                odd_found <= 1'b0;
            end else if (processing) begin
                if (index < len) begin
                    if (!even_found && (current_val[0] == 1'b0)) begin
                        first_even <= current_val;
                        even_found <= 1'b1;
                    end
                    if (!odd_found && (current_val[0] == 1'b1)) begin
                        first_odd <= current_val;
                        odd_found <= 1'b1;
                    end
                    index <= index + 1'b1;
                end else begin
                    if (even_found && odd_found) begin
                        result <= {8'd0, first_even} - {8'd0, first_odd};
                    end else if (even_found && !odd_found) begin
                        result <= {8'd0, first_even} - 16'hFFFF;
                    end else if (!even_found && odd_found) begin
                        result <= 16'hFFFF - {8'd0, first_odd};
                    end else begin
                        result <= 16'd0;
                    end
                    done <= 1'b1;
                    processing <= 1'b0;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule