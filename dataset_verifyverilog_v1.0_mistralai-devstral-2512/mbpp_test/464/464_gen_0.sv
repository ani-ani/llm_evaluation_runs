module dict_values_check(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] values [0:15],
    input wire signed [7:0] target,
    output reg result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] COMPARE = 4'd1;
    localparam [3:0] FINISH  = 4'd2;

    reg [3:0] state;
    reg [3:0] counter;
    reg [7:0] current_value;
    reg all_equal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            all_equal <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                        counter <= 4'd0;
                        all_equal <= 1'b1;
                    end
                end

                COMPARE: begin
                    current_value <= values[counter];
                    if (current_value != target) begin
                        all_equal <= 1'b0;
                    end

                    if (counter == 4'd15) begin
                        state <= FINISH;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                FINISH: begin
                    result <= all_equal;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule