module average_operations (
    input clk,
    input rst_n,
    input start,
    input [7:0] pattern,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] ITER    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    reg [1:0] state;
    reg [3:0] i;
    reg [15:0] sum;
    reg [2:0] q;

    reg [7:0] dist_rom [0:15];
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            sum <= 16'd0;
            result <= 32'd0;
            done <= 1'b0;
            for (j = 0; j < 16; j = j + 1) begin
                dist_rom[j] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 4'd0;
                        sum <= 16'd0;
                        state <= ITER;
                    end
                end

                ITER: begin
                    if (i < 4'd15) begin
                        if (match) sum <= sum + dist_rom[i];
                        i <= i + 1;
                    end else begin
                        if (match) sum <= sum + dist_rom[i];
                        i <= i + 1;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    case (q)
                        3'd0: result <= sum << 16;
                        3'd1: result <= sum << 15;
                        3'd2: result <= sum << 14;
                        3'd3: result <= sum << 13;
                        3'd4: result <= sum << 12;
                        default: result <= 32'd0;
                    endcase
                    state <= DONE;
                    done <= 1'b1;
                end

                DONE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        for (j = 0; j < 16; j = j + 1) begin
            case (j)
                4'd0:  dist_rom[j] = 8'd0;
                4'd1:  dist_rom[j] = 8'd1;
                4'd2:  dist_rom[j] = 8'd3;
                4'd3:  dist_rom[j] = 8'd2;
                4'd4:  dist_rom[j] = 8'd5;
                4'd5:  dist_rom[j] = 8'd4;
                4'd6:  dist_rom[j] = 8'd6;
                4'd7:  dist_rom[j] = 8'd3;
                4'd8:  dist_rom[j] = 8'd7;
                4'd9:  dist_rom[j] = 8'd6;
                4'd10: dist_rom[j] = 8'd8;
                4'd11: dist_rom[j] = 8'd5;
                4'd12: dist_rom[j] = 8'd10;
                4'd13: dist_rom[j] = 8'd7;
                4'd14: dist_rom[j] = 8'd9;
                4'd15: dist_rom[j] = 8'd4;
                default: dist_rom[j] = 8'd0;
            endcase
        end
    end

    reg match_reg;
    always @(*) begin
        match_reg = 1'b1;
        for (j = 0; j < 4; j = j + 1) begin
            case (pattern[2*j+1:2*j])
                2'b00: if (i[j] != 1'b0) match_reg = 1'b0;
                2'b01: if (i[j] != 1'b1) match_reg = 1'b0;
                default: ;
            endcase
        end
    end

    always @(*) begin
        q = 3'd0;
        for (j = 0; j < 4; j = j + 1) begin
            if (pattern[2*j+1:2*j] == 2'b10) q = q + 1;
        end
    end

    wire match = match_reg;

endmodule