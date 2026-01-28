module ReplaceDelimiters (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:15],
    input wire [3:0] length,
    output reg [7:0] output_str [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] counter;
    reg [3:0] length_reg;
    reg processing_done;

    // ASCII constants
    localparam [7:0] SPACE = 8'd32;
    localparam [7:0] COMMA = 8'd44;
    localparam [7:0] DOT = 8'd46;
    localparam [7:0] COLON = 8'd58;

    // Reset and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            length_reg <= 4'd0;
            done <= 1'b0;
            processing_done <= 1'b0;
            // Initialize output_str array elements
            output_str[0] <= 8'd0;
            output_str[1] <= 8'd0;
            output_str[2] <= 8'd0;
            output_str[3] <= 8'd0;
            output_str[4] <= 8'd0;
            output_str[5] <= 8'd0;
            output_str[6] <= 8'd0;
            output_str[7] <= 8'd0;
            output_str[8] <= 8'd0;
            output_str[9] <= 8'd0;
            output_str[10] <= 8'd0;
            output_str[11] <= 8'd0;
            output_str[12] <= 8'd0;
            output_str[13] <= 8'd0;
            output_str[14] <= 8'd0;
            output_str[15] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        counter <= 4'd0;
                        length_reg <= length;
                        processing_done <= 1'b0;
                    end
                end

                PROCESSING: begin
                    // Process one character per cycle
                    if (counter < length_reg) begin
                        // Character replacement logic
                        if ((input_str[counter] == SPACE) || 
                            (input_str[counter] == COMMA) || 
                            (input_str[counter] == DOT)) begin
                            output_str[counter] <= COLON;
                        end else begin
                            output_str[counter] <= input_str[counter];
                        end
                        counter <= counter + 4'd1;
                    end else begin
                        // Processing complete
                        processing_done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule