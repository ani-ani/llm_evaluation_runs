module grid_generator(
    input clk,
    input rst_n,
    input start,
    input [8:0] A,
    input [8:0] B,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] HEAD = 2'd1;
    localparam [1:0] GRID = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [3:0] header_index;
    reg [9:0] row;
    reg [9:0] col;
    reg [8:0] A_reg, B_reg;

    function automatic [7:0] f;
        input [9:0] i;
        input [9:0] j;
        input [8:0] A_val;
        input [8:0] B_val;
        reg [15:0] idx;
        begin
            if (i < 50) begin
                if (i[0] && j[0]) begin
                    idx = ((i-1) >> 1) * 50 + ((j-1) >> 1);
                    if (idx < (B_val - 1))
                        f = "#";
                    else
                        f = ".";
                end else
                    f = ".";
            end else begin
                if (i >= 51 && i <= 97 && i[0] && j[0]) begin
                    idx = ((i-51) >> 1) * 50 + ((j-1) >> 1);
                    if (idx < (A_val - 1))
                        f = ".";
                    else
                        f = "#";
                end else
                    f = "#";
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_out <= 1'b0;
            char_out <= 8'b0;
            header_index <= 4'd0;
            row <= 10'd0;
            col <= 10'd0;
            A_reg <= 9'd0;
            B_reg <= 9'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    if (start) begin
                        A_reg <= A;
                        B_reg <= B;
                        state <= HEAD;
                        header_index <= 4'd0;
                    end
                end
                HEAD: begin
                    valid_out <= 1'b1;
                    case (header_index)
                        4'd0: char_out <= "1";
                        4'd1: char_out <= "0";
                        4'd2: char_out <= "0";
                        4'd3: char_out <= " ";
                        4'd4: char_out <= "1";
                        4'd5: char_out <= "0";
                        4'd6: char_out <= "0";
                        4'd7: char_out <= "\n";
                        default: char_out <= 8'd0;
                    endcase
                    if (header_index < 4'd7)
                        header_index <= header_index + 4'd1;
                    else begin
                        header_index <= 4'd0;
                        state <= GRID;
                        row <= 10'd0;
                        col <= 10'd0;
                    end
                end
                GRID: begin
                    valid_out <= 1'b1;
                    if (col < 10'd100) begin
                        char_out <= f(row, col, A_reg, B_reg);
                        col <= col + 10'd1;
                    end else begin
                        char_out <= "\n";
                        col <= 10'd0;
                        row <= row + 10'd1;
                        if (row == 10'd99)
                            state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule