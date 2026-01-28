module substring_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] str_len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [31:0] product;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            product <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute product: str_len * (str_len + 1)
                    product <= $signed({16'd0, str_len}) * $signed({16'd0, str_len + 16'd1});
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    // Divide by 2 (right shift by 1)
                    result <= product[31:0] >> 1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule