module photo_validator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] length,
    input wire [127:0] packed_arr,
    output reg result,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INIT_I = 3'b001;
    localparam [2:0] CHECK_LEFT = 3'b010;
    localparam [2:0] CHECK_RIGHT = 3'b011;
    localparam [2:0] FOUND_VALID = 3'b100;
    localparam [2:0] DONE = 3'b101;

    reg [2:0] state;
    reg [3:0] i, j, k;
    reg [3:0] captured_len;
    reg [127:0] captured_arr;
    reg left_found;
    reg [7:0] left_min_above;
    reg right_found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            left_found <= 1'b0;
            left_min_above <= 8'd0;
            right_found <= 1'b0;
            captured_len <= 4'd0;
            captured_arr <= 128'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        captured_arr <= packed_arr;
                        captured_len <= length;
                        i <= 4'd0;
                        state <= INIT_I;
                    end
                end

                INIT_I: begin
                    if (i >= captured_len) begin
                        result <= 1'b0;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        left_found <= 1'b0;
                        left_min_above <= 8'hFF;
                        j <= 4'd0;
                        state <= CHECK_LEFT;
                    end
                end

                CHECK_LEFT: begin
                    if (j < i) begin
                        if (captured_arr[8*j +: 8] > captured_arr[8*i +: 8]) begin
                            left_found <= 1'b1;
                            if (captured_arr[8*j +: 8] < left_min_above)
                                left_min_above <= captured_arr[8*j +: 8];
                        end
                        j <= j + 4'd1;
                    end else begin
                        if (left_found) begin
                            k <= i + 4'd1;
                            right_found <= 1'b0;
                            state <= CHECK_RIGHT;
                        end else begin
                            i <= i + 4'd1;
                            state <= INIT_I;
                        end
                    end
                end

                CHECK_RIGHT: begin
                    if (k < captured_len) begin
                        if (captured_arr[8*k +: 8] > captured_arr[8*i +: 8] && captured_arr[8*k +: 8] > left_min_above) begin
                            right_found <= 1'b1;
                            state <= FOUND_VALID;
                        end else begin
                            k <= k + 4'd1;
                        end
                    end else begin
                        i <= i + 4'd1;
                        state <= INIT_I;
                    end
                end

                FOUND_VALID: begin
                    result <= 1'b1;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    if (!rst_n) begin
                        state <= IDLE;
                        result <= 1'b0;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule