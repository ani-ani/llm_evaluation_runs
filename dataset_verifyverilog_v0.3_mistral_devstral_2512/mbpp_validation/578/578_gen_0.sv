module interleave_3_arrays (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [7:0] arr3 [0:7],
    output reg [7:0] result,
    output reg valid,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] OUTPUT1 = 2'd1;
    localparam [1:0] OUTPUT2 = 2'd2;
    localparam [1:0] OUTPUT3 = 2'd3;
    localparam [1:0] DONE_STATE = 2'd0;

    reg [3:0] index;
    reg [1:0] state;
    reg [4:0] out_count;
    reg processing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            state <= IDLE;
            out_count <= 5'd0;
            processing <= 1'b0;
        end else begin
            valid <= 1'b0;
            done <= 1'b0;

            if (!processing) begin
                if (start) begin
                    processing <= 1'b1;
                    index <= 4'd0;
                    state <= OUTPUT1;
                    out_count <= 5'd0;
                end
            end else begin
                if (state != IDLE) begin
                    out_count <= out_count + 5'd1;
                end

                case (state)
                    OUTPUT1: begin
                        result <= arr1[index];
                        valid <= 1'b1;
                        state <= OUTPUT2;
                    end
                    OUTPUT2: begin
                        result <= arr2[index];
                        valid <= 1'b1;
                        state <= OUTPUT3;
                    end
                    OUTPUT3: begin
                        result <= arr3[index];
                        valid <= 1'b1;

                        if (index == len - 1) begin
                            if (out_count == (len * 3) - 1) begin
                                done <= 1'b1;
                                processing <= 1'b0;
                                state <= DONE_STATE;
                            end else begin
                                state <= DONE_STATE;
                            end
                        end else begin
                            index <= index + 4'd1;
                            state <= OUTPUT1;
                        end
                    end
                    default: begin
                        if (processing) begin
                            done <= 1'b1;
                            processing <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
endmodule