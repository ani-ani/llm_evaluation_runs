module multi_concat (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NEG = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [3:0] idx;
    reg [63:0] temp_result;
    reg sign_bit;
    reg [7:0] current_val;
    reg [7:0] abs_val;
    reg [7:0] tens;
    reg [7:0] ones;
    reg [15:0] decimal_val;
    reg [3:0] max_idx;

    // Combinational helper for negative check
    wire is_negative;
    assign is_negative = (len > 0) && (arr_0[7]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            idx <= 4'd0;
            temp_result <= 64'd0;
            sign_bit <= 1'b0;
            current_val <= 8'd0;
            abs_val <= 8'd0;
            tens <= 8'd0;
            ones <= 8'd0;
            decimal_val <= 16'd0;
            max_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    temp_result <= 64'd0;
                    sign_bit <= 1'b0;
                    max_idx <= (len > 8) ? 4'd8 : len;
                    if (start && (len > 0) && (len <= 8)) begin
                        state <= CHECK_NEG;
                    end
                end

                CHECK_NEG: begin
                    if (is_negative) begin
                        sign_bit <= 1'b1;
                    end else begin
                        sign_bit <= 1'b0;
                    end
                    state <= PROCESS;
                end

                PROCESS: begin
                    if (idx < max_idx) begin
                        // Select current array element
                        case (idx)
                            4'd0: current_val <= arr_0;
                            4'd1: current_val <= arr_1;
                            4'd2: current_val <= arr_2;
                            4'd3: current_val <= arr_3;
                            4'd4: current_val <= arr_4;
                            4'd5: current_val <= arr_5;
                            4'd6: current_val <= arr_6;
                            4'd7: current_val <= arr_7;
                            default: current_val <= 8'd0;
                        endcase

                        // Calculate absolute value (clamp to 99)
                        if (current_val[7]) begin
                            abs_val <= (~current_val + 8'd1);
                        end else begin
                            abs_val <= current_val;
                        end

                        // Clamp to 99
                        if (abs_val > 8'd99) begin
                            abs_val <= 8'd99;
                        end

                        // Convert to 2-digit decimal (tens*10 + ones)
                        tens <= abs_val / 8'd10;
                        ones <= abs_val % 8'd10;

                        // Shift decimal value into place
                        // decimal_val = tens * 10 + ones
                        // Each decimal takes 2 bytes: tens in upper byte, ones in lower byte
                        decimal_val <= ((tens << 4'd8) + ones);

                        // Shift and add to temp result
                        // Shift amount: (max_idx - 1 - idx) * 8 bits
                        if (idx == 0 && sign_bit) begin
                            // First element is negative - set sign bit in MSB of result
                            temp_result[63] <= 1'b1;
                            // Store magnitude in lower bytes
                            temp_result[62:0] <= (temp_result[62:0] + (decimal_val << ((max_idx - 4'd1 - idx) * 4'd8)));
                        end else begin
                            temp_result <= temp_result + (decimal_val << ((max_idx - 4'd1 - idx) * 4'd8));
                        end

                        idx <= idx + 4'd1;
                    end else begin
                        // Done processing all elements
                        result <= temp_result;
                        state <= FINISH;
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