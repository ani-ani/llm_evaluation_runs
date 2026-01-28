module StringFormatter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] data_in [0:15],
    input wire [63:0] prefix,
    input wire [63:0] suffix,
    output reg [63:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [4:0] IDLE      = 5'd0;
    localparam [4:0] PROCESS   = 5'd1;
    localparam [4:0] FINISH    = 5'd2;

    reg [4:0] state;
    reg [3:0] index;
    reg [7:0] char_value;
    reg [63:0] temp_result;
    reg [3:0] cycle_count;

    // ASCII conversion
    always @(*) begin
        case (data_in[index])
            4'd0: char_value = 8'd48; // '0'
            4'd1: char_value = 8'd49; // '1'
            4'd2: char_value = 8'd50; // '2'
            4'd3: char_value = 8'd51; // '3'
            4'd4: char_value = 8'd52; // '4'
            4'd5: char_value = 8'd53; // '5'
            4'd6: char_value = 8'd54; // '6'
            4'd7: char_value = 8'd55; // '7'
            4'd8: char_value = 8'd56; // '8'
            4'd9: char_value = 8'd57; // '9'
            4'd10: char_value = 8'd65; // 'A'
            4'd11: char_value = 8'd66; // 'B'
            4'd12: char_value = 8'd67; // 'C'
            4'd13: char_value = 8'd68; // 'D'
            4'd14: char_value = 8'd69; // 'E'
            4'd15: char_value = 8'd70; // 'F'
            default: char_value = 8'd32; // space
        endcase
    end

    // String construction
    always @(*) begin
        temp_result = {prefix[55:0], char_value, suffix[63:8]};
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            cycle_count <= 4'd0;
            done <= 1'b0;
            for (integer i = 0; i < 16; i = i + 1) begin
                result[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    result[index] <= temp_result;
                    if (index == 4'd15) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule