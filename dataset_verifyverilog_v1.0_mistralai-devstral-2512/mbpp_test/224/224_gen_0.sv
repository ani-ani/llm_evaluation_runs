module bit_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [3:0] accumulator;
    reg [3:0] bit_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            shift_reg <= 8'd0;
            accumulator <= 4'd0;
            bit_counter <= 4'd0;
            count <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        shift_reg <= n;
                        accumulator <= 4'd0;
                        bit_counter <= 4'd0;
                        state <= COUNTING;
                    end
                end

                COUNTING: begin
                    // Check LSB and accumulate
                    if (shift_reg[0]) begin
                        accumulator <= accumulator + 4'd1;
                    end

                    // Shift right and increment counter
                    shift_reg <= shift_reg >> 1;
                    bit_counter <= bit_counter + 4'd1;

                    // Check if all bits processed
                    if (bit_counter == 4'd8) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    count <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule