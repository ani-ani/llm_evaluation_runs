module move_zero(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_elements,
    input [15:0] input_array [15:0],
    output reg [15:0] output_array [15:0],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PASS1_COUNT = 3'b001;
    localparam PASS1_EXTRACT = 3'b010;
    localparam PASS2_FILL = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [3:0] idx;
    reg [3:0] count;
    reg [15:0] buffer [15:0];
    reg [3:0] write_ptr;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            count <= 4'd0;
            idx <= 4'd0;
            write_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                output_array[i] <= 16'd0;
                buffer[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PASS1_COUNT;
                        idx <= 4'd0;
                        count <= 4'd0;
                        write_ptr <= 4'd0;
                    end
                end

                PASS1_COUNT: begin
                    if (idx < num_elements) begin
                        if (input_array[idx] != 16'd0) begin
                            buffer[count] <= input_array[idx];
                            count <= count + 1'b1;
                        end
                        idx <= idx + 1'b1;
                    end else begin
                        state <= PASS1_EXTRACT;
                        idx <= 4'd0;
                    end
                end

                PASS1_EXTRACT: begin
                    if (idx < count) begin
                        output_array[idx] <= buffer[idx];
                        idx <= idx + 1'b1;
                    end else begin
                        state <= PASS2_FILL;
                        idx <= count;
                    end
                end

                PASS2_FILL: begin
                    if (idx < num_elements) begin
                        output_array[idx] <= 16'd0;
                        idx <= idx + 1'b1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule