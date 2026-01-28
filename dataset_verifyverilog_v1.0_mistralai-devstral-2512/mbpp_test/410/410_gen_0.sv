module min_int_finder(
    input clk,
    input rst_n,
    input [7:0] data [0:7],
    input [7:0] tags,
    output reg [7:0] min_val,
    output reg valid
);

    reg [2:0] counter;
    reg [7:0] current_min;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 3'd0;
            current_min <= 8'd0;
            found <= 1'b0;
            min_val <= 8'd0;
            valid <= 1'b0;
        end else begin
            if (counter < 3'd8) begin
                if (tags[counter] == 1'b1) begin
                    if (!found || data[counter] < current_min) begin
                        current_min <= data[counter];
                        found <= 1'b1;
                    end
                end
                counter <= counter + 3'd1;
            end else begin
                min_val <= current_min;
                valid <= found;
                counter <= 3'd0;
                current_min <= 8'd0;
                found <= 1'b0;
            end
        end
    end
endmodule