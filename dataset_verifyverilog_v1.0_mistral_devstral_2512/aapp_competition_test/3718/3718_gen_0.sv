module ball_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [63:0] sizes_flat,
    output reg result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CLEAR = 3'd1;
    localparam [2:0] MARK = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE = 3'd4;

    reg [2:0] state;
    reg [256:1] present;
    reg [5:0] n_reg;
    reg [63:0] sizes_flat_reg;
    reg [2:0] i;
    reg [7:0] current_size;

    wire any_three;
    assign any_three = |(present[1:254] & present[2:255] & present[3:256]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            present <= 256'b0;
            n_reg <= 6'd0;
            sizes_flat_reg <= 64'd0;
            i <= 3'd0;
            current_size <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        sizes_flat_reg <= sizes_flat;
                        state <= CLEAR;
                    end
                end

                CLEAR: begin
                    present <= 256'b0;
                    i <= 3'd0;
                    state <= MARK;
                end

                MARK: begin
                    if (i < n_reg && i < 3'd8) begin
                        current_size <= sizes_flat_reg[8*i +: 8];
                        if (current_size >= 8'd1 && current_size <= 8'd255) begin
                            present[current_size] <= 1'b1;
                        end
                        i <= i + 3'd1;
                    end else begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    result <= any_three;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule