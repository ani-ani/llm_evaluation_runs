module ExpectedGifts(
    input clk,
    input rst_n,
    input [3:0] n,
    input start,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOOKUP = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [15:0] result_reg;

    // LUT values for n=2 to 16 (Q8.8 format)
    reg [15:0] lut_value;
    always @(*) begin
        case (n)
            4'd2: lut_value = 16'd768;      // 3.0000
            4'd3: lut_value = 16'd1365;     // 5.3333
            4'd4: lut_value = 16'd2048;     // 8.0000
            4'd5: lut_value = 16'd2731;     // 10.668
            4'd6: lut_value = 16'd3413;     // 13.332
            4'd7: lut_value = 16'd4096;     // 16.000
            4'd8: lut_value = 16'd4779;     // 18.668
            4'd9: lut_value = 16'd5461;     // 21.332
            4'd10: lut_value = 16'd6144;    // 24.000
            4'd11: lut_value = 16'd6827;    // 26.668
            4'd12: lut_value = 16'd7509;    // 29.332
            4'd13: lut_value = 16'd8192;    // 32.000
            4'd14: lut_value = 16'd8875;    // 34.668
            4'd15: lut_value = 16'd9557;    // 37.332
            4'd16: lut_value = 16'd10240;   // 40.000
            default: lut_value = 16'd0;     // For n < 2 or n > 16
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            result_reg <= 16'd0;
        end else begin
            state <= next_state;
            result <= result_reg;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOOKUP;
                end else begin
                    next_state = IDLE;
                end
            end
            LOOKUP: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= 16'd0;
            done <= 1'b0;
        end else begin
            case (next_state)
                LOOKUP: begin
                    result_reg <= lut_value;
                    done <= 1'b0;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin // IDLE
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule