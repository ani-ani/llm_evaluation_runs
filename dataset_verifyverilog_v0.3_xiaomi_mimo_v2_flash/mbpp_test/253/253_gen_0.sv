module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [1:0] index;
    reg [3:0] count_reg;
    reg [7:0] current_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 2'd0;
            count_reg <= 4'd0;
            current_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 2'd0;
                    count_reg <= 4'd0;
                    if (start) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Get current value based on index
                    case (index)
                        2'd0: current_val <= arr_0;
                        2'd1: current_val <= arr_1;
                        2'd2: current_val <= arr_2;
                        2'd3: current_val <= arr_3;
                        default: current_val <= 8'd0;
                    endcase

                    // Count if value is an integer
                    // Heuristic: integer values are not ASCII printable (32-126)
                    if (current_val < 8'd32 || current_val > 8'd126) begin
                        count_reg <= count_reg + 4'd1;
                    end

                    if (index < 2'd3) begin
                        index <= index + 2'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule