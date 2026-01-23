module photo_finder (
    input clk,
    input rst_n,
    input start,
    input [2:0] photo_index,
    input [2:0] num_people,
    input [15:0] heights [0:7],
    output reg [2:0] valid_photo_index,
    output reg valid,
    output reg done
);

    reg [2:0] me;
    reg [2:0] i;
    reg [2:0] j;
    reg found;
    reg [2:0] valid_photo_index_reg;
    reg valid_reg;
    reg done_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            me <= 3\'d0;
            i <= 3\'d0;
            j <= 3\'d0;
            found <= 0;
            valid_photo_index_reg <= 3\'d0;
            valid_reg <= 0;
            done_reg <= 0;
        end else begin
            if (start) begin
                me <= 3\'d0;
                i <= 3\'d0;
                j <= 3\'d0;
                found <= 0;
                valid_photo_index_reg <= 3\'d0;
                valid_reg <= 0;
                done_reg <= 0;
            end
            if (!found && !done_reg) begin
                if (me >= num_people) begin
                    found <= 1;
                    done_reg <= 1;
                    valid_reg <= 0;
                end else begin
                    if (i >= me) begin
                        me <= me + 1;
                        i <= 3\'d0;
                        j <= 3\'d0;
                    end else begin
                        if (heights[i] > heights[me]) begin
                            if (j < (me + 1)) begin
                                j <= me + 1;
                            end else if (j < num_people) begin
                                if (heights[j] > heights[me] && heights[j] > heights[i]) begin
                                    found <= 1;
                                    valid_photo_index_reg <= photo_index;
                                    valid_reg <= 1;
                                    done_reg <= 1;
                                end
                                j <= j + 1;
                            end else begin
                                i <= i + 1;
                            end
                        end else begin
                            i <= i + 1;
                        end
                    end
                end
            end
        end
    end

    assign valid_photo_index = valid_photo_index_reg;
    assign valid = valid_reg;
    assign done = done_reg;

endmodule