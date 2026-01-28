module string_to_tuple(
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] input_string,
    input [3:0] input_length,
    output reg [15:0][7:0] output_tuple,
    output reg [3:0] output_length,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LATCH    = 3'd1;
    localparam [2:0] PROCESS  = 3'd2;
    localparam [2:0] FINISH   = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] idx;           // Input character index
    reg [3:0] out_idx;       // Output character index
    reg [15:0][7:0] input_reg;    // Latched input
    reg [3:0] input_len_reg;      // Latched length
    reg [7:0] char;          // Current character
    reg is_whitespace;       // Whitespace detection flag
    reg [7:0] max_idx;       // Maximum index to process

    // Whitespace detection combinational logic
    always @(*) begin
        char = input_reg[idx];
        is_whitespace = (char == 8'h20) || (char == 8'h09) || (char == 8'h0A);
    end

    // State machine and processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            output_length <= 4'd0;
            output_tuple[0] <= 8'd0;
            output_tuple[1] <= 8'd0;
            output_tuple[2] <= 8'd0;
            output_tuple[3] <= 8'd0;
            output_tuple[4] <= 8'd0;
            output_tuple[5] <= 8'd0;
            output_tuple[6] <= 8'd0;
            output_tuple[7] <= 8'd0;
            output_tuple[8] <= 8'd0;
            output_tuple[9] <= 8'd0;
            output_tuple[10] <= 8'd0;
            output_tuple[11] <= 8'd0;
            output_tuple[12] <= 8'd0;
            output_tuple[13] <= 8'd0;
            output_tuple[14] <= 8'd0;
            output_tuple[15] <= 8'd0;
            idx <= 4'd0;
            out_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    output_length <= 4'd0;
                    if (start) begin
                        state <= LATCH;
                    end else begin
                        state <= IDLE;
                    end
                end

                LATCH: begin
                    // Latch input data
                    input_reg <= input_string;
                    input_len_reg <= input_length;
                    idx <= 4'd0;
                    out_idx <= 4'd0;
                    // Initialize output tuple to zeros
                    output_tuple[0] <= 8'd0;
                    output_tuple[1] <= 8'd0;
                    output_tuple[2] <= 8'd0;
                    output_tuple[3] <= 8'd0;
                    output_tuple[4] <= 8'd0;
                    output_tuple[5] <= 8'd0;
                    output_tuple[6] <= 8'd0;
                    output_tuple[7] <= 8'd0;
                    output_tuple[8] <= 8'd0;
                    output_tuple[9] <= 8'd0;
                    output_tuple[10] <= 8'd0;
                    output_tuple[11] <= 8'd0;
                    output_tuple[12] <= 8'd0;
                    output_tuple[13] <= 8'd0;
                    output_tuple[14] <= 8'd0;
                    output_tuple[15] <= 8'd0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    // Process each input character
                    if (idx < input_len_reg) begin
                        if (!is_whitespace) begin
                            // Not whitespace, add to output
                            if (out_idx < 4'd16) begin
                                output_tuple[out_idx] <= char;
                                out_idx <= out_idx + 4'd1;
                            end
                        end
                        idx <= idx + 4'd1;
                        state <= PROCESS;
                    end else begin
                        // Done processing all characters
                        output_length <= out_idx;
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